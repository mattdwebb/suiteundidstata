*! Native suite development adapter 0.1.0, 29sep2026
program define suite_undid, eclass sortpreserve
    version 16.0
    syntax varlist(numeric min=1) [if] [in], TIME(varname numeric) CLuster(varname) ///
        [GVAR(varname numeric) TREATment(varname numeric) IVAR(varname) ///
        DATAMode(string) INference(string) ASSIGNments(name) ///
        REPS(integer 999) SEED(integer 0) EXACT NULL(real 0) CCC(string) COHORTFirst]
    if "`gvar'" == "" & "`treatment'" == "" {
        di as error "INVALID_INPUT: supply gvar or treatment"
        exit 198
    }
    if "`ccc'" != "" & "`ccc'" != "int" {
        di as error "UNSUPPORTED: Stata adapter currently supports CCC int only"
        exit 198
    }
    if "`datamode'" == "" | "`datamode'" == "auto" {
        if "`ivar'" == "" local datamode rcs
        else local datamode panel
    }
    if !inlist("`datamode'","panel","rcs") {
        di as error "INVALID_INPUT: datamode must be panel, rcs, or auto"
        exit 198
    }
    if "`datamode'" == "panel" & "`ivar'" == "" {
        di as error "UNSUPPORTED: panel requires ivar"
        exit 198
    }
    if "`inference'" == "" local inference point
    if "`inference'" == "standard" local inference native jackknife
    if "`inference'" == "full" local inference native jackknife ri_beta ri_t_native
    foreach method of local inference {
        if !inlist("`method'","point","native","jackknife","ri_beta","ri_t_native") {
            di as error "UNSUPPORTED: unknown inference method"
            exit 198
        }
    }
    if `reps' < 1 {
        di as error "INVALID_INPUT: reps must be positive"
        exit 198
    }
    marksample touse, novarlist
    quietly count if `touse' & missing(`cluster')
    if r(N) {
        di as error "INVALID_INPUT: missing cluster"
        exit 459
    }
    tempvar sid iid
    quietly egen long `sid' = group(`cluster') if `touse'
    local unitarg ""
    if "`ivar'" != "" {
        quietly count if `touse' & missing(`ivar')
        if r(N) exit 459
        quietly egen long `iid' = group(`ivar') if `touse'
        local unitarg `iid'
    }
    tempname RES DEL DRAWS CELLS ASSN b
    local rngstate = c(rngstate)
    quietly set seed `seed'
    local ex = ("`exact'" != "")
    capture noisily mata: _sundid_run("`varlist'","`time'","`sid'","`gvar'", ///
        "`treatment'","`unitarg'","`touse'","`assignments'","`inference'", ///
        `reps',`ex',1,`null',("`cohortfirst'"!=""),"`RES'","`DEL'","`DRAWS'","`CELLS'","`ASSN'")
    local rc = _rc
    quietly set rngstate `rngstate'
    if `rc' exit `rc'
    matrix `b' = `RES'[1,1]
    matrix colnames `b' = estimate
    quietly levelsof `cluster' if `touse', local(cluster_order)
    tempvar tagcell
    quietly egen byte `tagcell'=tag(`cluster' `time') if `touse'
    if "`gvar'"!="" quietly count if `tagcell'==1 & `gvar'>0 & `time'>=`gvar'
    else quietly count if `tagcell'==1 & `treatment'==1
    local eligible_count=r(N)
    ereturn post `b', esample(`touse')
    ereturn scalar estimate = `RES'[1,1]
    ereturn scalar N = `RES'[1,2]
    ereturn scalar N_clust = `RES'[1,3]
    ereturn scalar jackknife_se = `RES'[1,4]
    ereturn scalar jackknife_t = `RES'[1,5]
    ereturn scalar jackknife_p = `RES'[1,6]
    ereturn scalar jackknife_df = `RES'[1,7]
    ereturn scalar ri_beta_p = `RES'[1,8]
    ereturn scalar ri_beta_hits = `RES'[1,9]
    ereturn scalar ri_reps = `RES'[1,10]
    ereturn scalar jackknife_status = `RES'[1,11]
    ereturn scalar ri_beta_status = `RES'[1,12]
    ereturn scalar assignment_space = `RES'[1,13]
    ereturn scalar native_se = .
    ereturn scalar native_p = .
    ereturn scalar ri_t_native_p = .
    matrix colnames `CELLS' = cluster g t base estimate target_weight normalized_weight controls_used controls_eligible
    matrix colnames `DRAWS' = beta
    ereturn scalar n_cells_eligible=`eligible_count'
    ereturn scalar n_cells_used=rowsof(`CELLS')
    ereturn matrix att_st = `CELLS'
    ereturn matrix delete_estimates = `DEL'
    ereturn matrix ri_statistics = `DRAWS'
    ereturn matrix assignments = `ASSN'
    ereturn local cmd suite_undid
    ereturn local estimator_version "0.1.0"
    ereturn local cluster_order `"`cluster_order'"'
    ereturn local native_method "UNSUPPORTED"
    ereturn local data_mode "`datamode'"
    ereturn local target_label "ATT(s,t)-first; target-cell size weights"
    ereturn local support_policy "estimable state-year contrasts and control comparisons"
    if "`cohortfirst'"!="" ereturn local target_label "simple cohort-time ATT; two-period within-cohort weights"
    ereturn local covariate_mode "silo-specific pair slopes"
    ereturn local status "PASS"
    di as text "UNDID estimate: " as result %12.8g e(estimate)
end

version 16.0
mata:
void _sundid_fail(string scalar message)
{
    errprintf("%s\n", message)
    _error(3498)
}

real matrix _sundid_cells(real colvector y, real matrix X, real colvector s,
    real colvector ti, real colvector times, real colvector a,
    real scalar kind, real scalar omit, real scalar cohortfirst)
{
    real scalar G,T,q,j,t,c,b,i,h,postid,preid,weight,effect,eligible
    real colvector active, controls, cohorts, orderidx, keys, ix, block, treated
    real colvector n, means, delta, usable, cw
    real rowvector target, test
    real matrix ranges, Z, fit, inverse, coef, nullspace, localmean, result
    G=rows(a); T=rows(times); q=1+cols(X)
    active=selectindex((1::G):!=omit)
    controls=select(active,a[active]:==0)
    cohorts=uniqrows(sort(select(a[active],a[active]:>0),1))
    result=J(0,8,.)
    if (!rows(controls) | !rows(cohorts)) return(result)
    keys=(s:-1)*T+ti
    orderidx=order(keys,1)
    ranges=panelsetup(keys[orderidx],1)
    n=J(G*T,1,0); means=J(G*T,1,.)
    localmean=coef=J(G*T,q,0)
    nullspace=J(G*T*q,q,0)
    // Store the sample slice and, for standardization, the unidentified directions.
    fit=J(G*T,2,.)
    for (h=1;h<=rows(ranges);h++) {
        ix=orderidx[|ranges[h,1]\ranges[h,2]|]
        j=keys[ix[1]]
        fit[j,.]=ranges[h,.]; n[j]=rows(ix); means[j]=mean(y[ix])
        if (kind==2 & cols(X)>0) {
            Z=(J(rows(ix),1,1),X[ix,.])
            inverse=pinv(Z)
            coef[j,.]=(inverse*y[ix])'
            localmean[j,.]=mean(Z)
            block=((j-1)*q+1::j*q)
            nullspace[block,.]=I(q)-inverse*Z
        }
    }
    for (c=1;c<=rows(cohorts);c++) {
        ix=selectindex(times:<cohorts[c])
        if (!rows(ix)) continue
        b=ix[rows(ix)]
        treated=select(active,a[active]:==cohorts[c])
        for (t=1;t<=T;t++) {
            if (times[t]<cohorts[c]) continue
            delta=J(G,1,.)
            if (kind==1 | !cols(X)) {
                for (h=1;h<=rows(active);h++) {
                    i=active[h]; preid=(i-1)*T+b; postid=(i-1)*T+t
                    if (!n[preid] | !n[postid]) continue
                    if (!cols(X)) delta[i]=means[postid]-means[preid]
                    else {
                        ix=(orderidx[|fit[preid,1]\fit[preid,2]|]\orderidx[|fit[postid,1]\fit[postid,2]|])
                        Z=(J(rows(ix),1,1),ti[ix]:==t,X[ix,.])
                        inverse=pinv(Z)
                        test=I(cols(Z))[2,.]
                        if (max(abs(test-inverse[2,.]*Z))<=1e-9)
                            delta[i]=inverse[2,.]*y[ix]
                    }
                }
            }
            eligible=rows(result)+1
            for (h=1;h<=rows(treated);h++) {
                i=treated[h]; postid=(i-1)*T+t; preid=(i-1)*T+b
                if (!n[preid] | !n[postid]) continue
                if (kind==2 & cols(X)>0) {
                    target=localmean[postid,.]
                    delta=J(G,1,.)
                    ix=(i\controls)
                    for (j=1;j<=rows(ix);j++) {
                        preid=(ix[j]-1)*T+b; postid=(ix[j]-1)*T+t
                        if (!n[preid] | !n[postid]) continue
                        if (max(abs(target*nullspace[| (preid-1)*q+1,1 \ preid*q,q |]))>1e-9*max((1,max(abs(target))))) continue
                        if (max(abs(target*nullspace[| (postid-1)*q+1,1 \ postid*q,q |]))>1e-9*max((1,max(abs(target))))) continue
                        delta[ix[j]]=target*(coef[postid,.]-coef[preid,.])'
                    }
                }
                if (delta[i]>=.) continue
                usable=select(controls,delta[controls]:<.)
                if (!rows(usable)) continue
                cw=n[(usable:-1)*T:+t]+n[(usable:-1)*T:+b]
                effect=delta[i]-sum(cw:*delta[usable])/sum(cw)
                weight=n[(i-1)*T+t]
                result=result\(i,cohorts[c],times[t],times[b],effect,weight,rows(usable),rows(controls))
            }
            if (cohortfirst & eligible<=rows(result)) {
                ix=(eligible::rows(result)); treated=result[ix,1]
                cw=n[(treated:-1)*T:+b]+n[(treated:-1)*T:+t]
                result[ix,6]=sum(result[ix,6])*cw/sum(cw)
                treated=select(active,a[active]:==cohorts[c])
            }
        }
    }
    return(result)
}

real scalar _sundid_point(real colvector y, real matrix X, real colvector s,
    real colvector ti, real colvector times, real colvector a,
    real scalar kind, real scalar omit, real scalar cohortfirst)
{
    real matrix r
    r=_sundid_cells(y,X,s,ti,times,a,kind,omit,cohortfirst)
    if (rows(r)==0) return(.)
    return(sum(r[,5]:*r[,6])/sum(r[,6]))
}

real rowvector _sundid_jk(real colvector y, real matrix X, real colvector s,
    real colvector ti, real colvector times, real colvector a,
    real scalar kind, real scalar null, real scalar cohortfirst)
{
    real scalar G,i,est,se,stat,p,status
    real colvector deleted
    G=rows(a); deleted=J(G,1,.)
    est=_sundid_point(y,X,s,ti,times,a,kind,0,cohortfirst)
    for (i=1;i<=G;i++) deleted[i]=_sundid_point(y,X,s,ti,times,a,kind,i,cohortfirst)
    se=stat=p=.; status=1
    if (!any(deleted:>=.)) {
        se=sqrt((G-1)/G*sum((deleted:-mean(deleted)):^2))
        if (se<=64*2.220446049250313e-16*max((1,abs(est),max(abs(deleted))))) status=2
        else {
            stat=(est-null)/se
            p=2*ttail(G-1,abs(stat))
            status=0
        }
    }
    return((se,stat,p,status,deleted'))
}

real matrix _sundid_draws(real colvector a, real scalar reps, real scalar exact)
{
    real scalar G,space,i,j,z,tmp,B,tries,count,duplicate
    real colvector labels,v,draw
    real matrix out
    G=rows(a); labels=uniqrows(sort(a,1))
    space=lngamma(G+1)
    for (i=1;i<=rows(labels);i++) space=space-lngamma(sum(a:==labels[i])+1)
    space=round(exp(space))
    B=min((reps,space-1))
    if (exact | reps>=space-1) {
        if (space>100000 | space>=.) _sundid_fail("UNSUPPORTED: exact space exceeds 100000")
        out=J(space-1,G,.); count=0; v=sort(a,1)
        while (1) {
            if (any(v:!=a)) {
                count++
                out[count,.]=v'
            }
            i=G-1
            while (i>0) {
                if (v[i]<v[i+1]) break
                i--
            }
            if (i==0) break
            j=G
            while (v[j]<=v[i]) j--
            tmp=v[i]; v[i]=v[j]; v[j]=tmp
            i++; j=G
            while (i<j) {
                tmp=v[i]; v[i]=v[j]; v[j]=tmp
                i++; j--
            }
        }
        return(out)
    }
    if (B>100000) _sundid_fail("UNSUPPORTED: draw budget exceeds 100000")
    out=J(B,G,.); count=tries=0
    while (count<B) {
        tries++
        if (tries>max((10000,100*B))) _sundid_fail("NUMERICAL_FAILURE: sampling retry budget exhausted")
        draw=a[order(runiform(G,1),1)]
        if (all(draw:==a)) continue
        duplicate=0
        for (z=1;z<=count;z++) if (all(out[z,.]:==draw')) duplicate=1
        if (duplicate) continue
        count++; out[count,.]=draw'
    }
    return(out)
}

void _sundid_run(string scalar vars, string scalar timevar, string scalar svar,
    string scalar gvar, string scalar dvar, string scalar ivar,
    string scalar touse, string scalar assname, string scalar inf,
    real scalar reps, real scalar exact, real scalar kind, real scalar null, real scalar cohortfirst,
    string scalar resname, string scalar delname, string scalar drawname,
     string scalar cellname, string scalar assout)
{
    real matrix YX,X,ass,cell,stats,check
    real colvector y,s,rawtime,times,ti,a,gv,dv,iv,ix,ds,pos,labels,ids
    real rowvector jk
    real scalar G,T,N,i,t,g,B,r,est,betap,bhits,tol,bstatus,space
    YX=st_data(.,tokens(vars),touse); y=YX[,1]
    N=rows(y)
    if (cols(YX)>1) X=YX[,2..cols(YX)]
    else X=J(N,0,.)
    s=st_data(.,svar,touse); rawtime=st_data(.,timevar,touse)
    if (N==0 | any(YX:>=.) | any(rawtime:>=.) | any(s:>=.))
        _sundid_fail("INVALID_INPUT: empty sample or missing required values")
    G=max(s); times=uniqrows(sort(rawtime,1)); T=rows(times)
    ti=J(N,1,.)
    for (t=1;t<=T;t++) {
        ix=selectindex(rawtime:==times[t]); ti[ix]=J(rows(ix),1,t)
    }
    if (ivar!="") {
        iv=st_data(.,ivar,touse); ids=uniqrows(sort(iv,1))
        if (any(iv:>=.)) _sundid_fail("INVALID_INPUT: missing unit")
        for (i=1;i<=rows(ids);i++) {
            ix=selectindex(iv:==ids[i])
            if (rows(uniqrows(sort(s[ix],1)))!=1 | rows(uniqrows(sort(ti[ix],1)))!=rows(ix))
                _sundid_fail("INVALID_INPUT: duplicate unit-time or unit changes cluster")
        }
    }
    if (gvar!="") gv=st_data(.,gvar,touse)
    if (dvar!="") dv=st_data(.,dvar,touse)
    a=J(G,1,0)
    for (i=1;i<=G;i++) {
        ix=selectindex(s:==i)
        if (gvar!="") {
            if (any(gv[ix]:>=.) | any(gv[ix]:<0) | min(gv[ix])!=max(gv[ix]))
                _sundid_fail("INVALID_INPUT: gvar not cluster-constant, finite, nonnegative")
            a[i]=gv[ix[1]]
        }
        ds=J(T,1,0)
        for (t=1;t<=T;t++) {
            ix=selectindex((s:==i):&(ti:==t))
            if (rows(ix)==0) {
                ds[t]=.
                continue
            }
            if (dvar!="") {
                if (any((dv[ix]:!=0):&(dv[ix]:!=1)) | min(dv[ix])!=max(dv[ix]))
                    _sundid_fail("INVALID_INPUT: treatment must be binary and cell-constant")
                ds[t]=dv[ix[1]]
            }
        }
        if (dvar!="") {
            pos=selectindex(ds:<.)
            for (t=2;t<=rows(pos);t++) if (ds[pos[t]]<ds[pos[t-1]])
                _sundid_fail("INVALID_INPUT: nonabsorbing treatment")
            if (gvar=="") {
                pos=selectindex(ds:==1)
                if (rows(pos)>0) a[i]=times[pos[1]]
            }
            else if (any(select(ds:!=((a[i]>0):&(times:>=a[i])),ds:<.)))
                _sundid_fail("INVALID_INPUT: treatment disagrees with gvar")
        }
        if (a[i]>0 & (sum(times:<a[i])==0 | sum(times:>=a[i])==0))
            _sundid_fail("IDENTIFICATION_FAILURE: cohort needs pre and post")
    }
    if (sum(a:>0)==0 | sum(a:==0)==0)
        _sundid_fail("IDENTIFICATION_FAILURE: treated and never clusters required")
    cell=_sundid_cells(y,X,s,ti,times,a,kind,0,cohortfirst)
    if (rows(cell)==0) _sundid_fail("IDENTIFICATION_FAILURE: no estimable treated state-year comparison")
    est=sum(cell[,5]:*cell[,6])/sum(cell[,6])
    cell=(cell[,1..6],cell[,6]/sum(cell[,6]),cell[,7..8])
    jk=J(1,4+G,.); betap=.; bhits=.; B=0
    bstatus=.
    if (strpos(inf,"jackknife"))
        jk=_sundid_jk(y,X,s,ti,times,a,kind,null,cohortfirst)
    ass=J(1,G,.); stats=J(1,1,.)
    if (strpos(inf,"ri_beta")) {
        if (null!=0) _sundid_fail("UNSUPPORTED: randomization supports zero null only")
        if (assname!="") ass=st_matrix(assname)
        else ass=_sundid_draws(a,reps,exact)
        B=rows(ass)
        if (cols(ass)!=G | B<1 | any(ass:>=.))
            _sundid_fail("INVALID_INPUT: assignments require finite B by G matrix")
        if (rows(uniqrows(sort(ass,1..G)))!=B)
            _sundid_fail("INVALID_INPUT: duplicate assignment")
        for (r=1;r<=B;r++) {
            if (any(sort(ass[r,.]',1):!=sort(a,1)) | all(ass[r,.]':==a))
                _sundid_fail("INVALID_INPUT: assignment counts changed or observed included")
        }
        stats=J(B,1,.)
        for (r=1;r<=B;r++) {
            stats[r,1]=_sundid_point(y,X,s,ti,times,ass[r,.]',kind,0,cohortfirst)
        }
        bhits=0; bstatus=0
        for (r=1;r<=B;r++) {
            tol=64*2.220446049250313e-16*max((1,abs(est),abs(stats[r,1])))
            if (stats[r,1]>=.) bstatus=1
            else if (abs(stats[r,1])>=abs(est)-tol) bhits++
        }
        if (bstatus==0) betap=(1+bhits)/(B+1)
        if (!strpos(inf,"ri_beta")) betap=bhits=bstatus=.
    }
    labels=uniqrows(sort(a,1)); space=lngamma(G+1)
    for (i=1;i<=rows(labels);i++) space=space-lngamma(sum(a:==labels[i])+1)
    space=round(exp(space))
    st_matrix(resname,(est,N,G,jk[1..3],G-1,betap,bhits,B,jk[4],bstatus,space))
    st_matrix(delname,jk[5..4+G]')
    st_matrix(drawname,stats)
    st_matrix(cellname,cell)
    st_matrix(assout,ass)
}
end
