%% Clears and Comments
clear;
clf;
%This code outputs probability distribution of what fraction of the photons
%in a FLIM histogram came from short lifetime photons

tic

if ispc ==1
    matnums_list = [7554];%Enter matin number here 
else %Used for running this code on a cluster
    matnum = getenv('SLURM_ARRAY_TASK_ID')
    outMatName = strcat('/n/regal/needleman_lab/bkaye/matout/matout',matnum,'.mat');
    inMatName = strcat('/n/regal/needleman_lab/bkaye/matin/matin',matnum,'.mat');
    matnums_list = 1;
end


for matnum_ind = matnums_list
    if ispc==1
    matnum = num2str(matnum_ind);
    fprintf('%s\n',matnum);
    outMatName = strcat('Y:\Users\bkaye\cluster\matout\matout',matnum,'.mat');
    inMatName = strcat('Y:\Users\bkaye\cluster\matin\matin',matnum,'.mat');
    end
    
    load(inMatName);
    jmax = input(1,1,1).jmax;
    exptmax = input(1,1,1).exptmax;
    cyclesmax = input(1,1,1).cyclesmax;
    
    output = input;
    output(cyclesmax,exptmax,jmax).prBest = pi;
    output(cyclesmax,exptmax,jmax).w2Best = pi;
    output(cyclesmax,exptmax,jmax).w1Best = pi;
    prBestmat = pi*ones(cyclesmax,exptmax,jmax);
    w2Bestmat = pi*ones(cyclesmax,exptmax,jmax);
    w1Bestmat = pi*ones(cyclesmax,exptmax,jmax);
    
    for jind = 1:jmax
        for expt = 1:exptmax
            for cindex = 1:cyclesmax
                
                p =input(cindex,expt,jind).datahis;
                ga =input(cindex,expt,jind).ga; %ga is name of vector of shifted irf
                r1l = input(cindex,expt,jind).r1l; %int in units of laser pulse periods
                r2l = input(cindex,expt,jind).r2l; %int in units of laser pulse periods
                r1s = input(cindex,expt,jind).r1s; %int in units of laser pulse periods
                r2s = input(cindex,expt,jind).r2s; %int in units of laser pulse periods
                
                for l1 = 1:2
                    %% Scan Parameters and Simulation Variables/Load Data
                    if l1 == 1
                        w1step= input(cindex,expt,jind).w1step; w1min=input(cindex,expt,jind).w1min; w1max=input(cindex,expt,jind).w1max;
                        w2step=input(cindex,expt,jind).w2step; w2min=input(cindex,expt,jind).w2min; w2max=input(cindex,expt,jind).w2max;
                        prstep=input(cindex,expt,jind).prstep; prmin=input(cindex,expt,jind).prmin; prmax=input(cindex,expt,jind).prmax;
                        w02step=input(cindex,expt,jind).w02step; w02min=input(cindex,expt,jind).w02min; w02max=input(cindex,expt,jind).w02max;
                        extstep=input(cindex,expt,jind).extstep; extmin=input(cindex,expt,jind).extmin; extmax=input(cindex,expt,jind).extmax;
                        thr=input(cindex,expt,jind).thr; fracstep=input(cindex,expt,jind).fracstep;
                        bins = input(cindex,expt,jind).bins;
                        brem =input(cindex,expt,jind).brem; binskeep = bins-brem;
                        wig = input(cindex,expt,jind).wig;
                        T = 12.58; %Used in both and sim and real data
                    else
                        [w1step, w2step, prstep, w02step, extstep] =...
                            newstepsize(w1max,w1min,w2max,w2min,prmax,prmin,w02max,w02min,extmax,extmin,lw1,lw2,lpr,lw02,lext);
                    end
                    
                    %% Calculate Post
                    
                    %Initialize loglike
                    loglike = -pi*ones(round(1+(w1max-w1min)/w1step),round(1+(w2max-w2min)/w2step),...
                        round(1+(w02max-w02min)/w02step),...
                        round(1+(prmax-prmin)/prstep),round(1+(extmax-extmin)/extstep));
                    
                    s = T/bins:T/bins:T; %time vector used to generate PDF of signal exponential
                    
                    tfw =input(cindex,expt,jind).tfw; %forward amount of time to remove
                    tbac =input(cindex,expt,jind).tbac; %backwards amount of time to remove
                    [srem,erem,p2,wig2] = remove_bins(T,bins,tfw,tbac,p,wig); %returns data, wigs, and indeces of which bins to keep/remove
                    binsl = binskeep - (erem-srem); %binskeep is number of bins in recording window, binsl if isnumber of bins in recording window
                    %after removing small time bins
                    
                    c = binsl/bins; %fraction of background photons that arrive in detectable time-bins
                    p2 = p2./wig2;
                    
                    for w2i = w2min:w2step:w2max
                        % clear f2;
                        f2t = exp(-s/w2i); %signal over one period
                        f2 = [f2t f2t]; %signal over 2 consecutive periods
                        f2con = conv(f2,ga); %PDF after conv
                        f2bar = f2con(bins+1:2*bins); %pdf after mod-ing by laser period
                        f2ha = f2bar(1:binskeep); %Keep only the appropriate bins
                        f2h = [f2ha(1:srem-1),f2ha(erem:end)];
                        b = 1; %Fraction of photons from w02 that arrive in detection window
                        f2h = f2h/sum(f2h); %Normalized PDF of detecting a photon in a bin given photon came from w2 (non-FRET)
                        cf2h = fliplr(cumsum(fliplr(f2h))); %for int correction
                        f2h2 = f2h.*cf2h/sum(f2h.*cf2h); %fliplr(cumsum(fliplr(f2h))) is CDF.
                        f2hr = f2h*r1l + f2h2*r2l; %f2h and f2h2 are both normalized. Since r1l+r2l =1, f2hr is normalized
                        
                        %SEARCH OVER W1,W02,W00
                        for w1i = w1min:w1step:w1max
                            f1t = exp(-s/w1i);
                            f1 = [f1t f1t];
                            fcon = conv(f1,ga);
                            fbar = fcon(bins+1:2*bins);
                            fha = fbar(1:binskeep);
                            fhb = [fha(1:srem-1),fha(erem:end)];
                            a = 1; %Fraction of photons from w02 that arrive in detection window
                            fh = fhb/sum(fhb);
                            cfh = fliplr(cumsum(fliplr(fh))); %for int correction
                            fh2 = fh.*cfh/sum(fh.*cfh);
                            fhr = fh*r1s + fh2*r2s;
                            
                            for w02i = w02min:w02step:w02max
                                for pri = prmin:prstep:prmax
                                    for exti = extmin:extstep:extmax
                                        if pri+ w02i > 1 % +exti
                                            loglike(round(1+(w1i-w1min)/w1step),round(1+(w2i-w2min)/w2step), round(1+(w02i-w02min)/w02step),...
                                                round(1+(pri-prmin)/prstep),round(1+(exti-extmin)/extstep)) = -inf;
                                        else
                                            %Note that: w01 = pri
                                            w00 = 1 - pri - w02i;
                                            rd = 1/(a*pri+b*w02i+c*w00);% "rd" stands for "reciprocal d"
                                            loglike(round(1+(w1i-w1min)/w1step),round(1+(w2i-w2min)/w2step), round(1+(w02i-w02min)/w02step),...
                                                round(1+(pri-prmin)/prstep),round(1+(exti-extmin)/extstep)) =...
                                                sum(log((a*pri*fhr + b*w02i*f2hr + c*w00/binsl)*rd).*p2); %removed exti*ext from like
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    loglike(isnan(loglike)) = -inf;
                    if l1 ==1
                        [error6_l1,error7_l1] = checkloglike2(loglike); %check's loglike for matrix size errors (makes sure entire space is scanned)
                    else
                        [error6_l2,error7_l2] = checkloglike2(loglike);
                    end
                    
                    loglike2 = loglike - max(max(max(max(max(loglike))))); %Sets max of like to 1.
                    like = exp(loglike2);
                    
                    %%%%%% Priors & Posteriors %%%%%%
                    %prior = ones(round(1+(w1max-w1min)/w1step),round(1+(w2max-w2min)/w2step),round(1+(w02max-w02min)/w02step),round(1+(prmax-prmin)/prstep),round(1+(extmax-extmin)/extstep)); %Ini Properly
                    post = like; %post = like.*prior;
                    
                    
                    %% Marg and Plots
                    
                    [prest, prBesti, prBest, prestx, w1est, w1Besti,w1Best, w1estx, w2est,w2Besti,w2Best, w2estx,...
                        w02est,w02Besti,w02Best, w02estx, extest,extBesti,extBest,extestx] =...
                        marg(post,prstep,prmin,prmax,w1step,w1min,w1max,w2step,w2min,w2max,...
                        w02step,w02min,w02max,extstep,extmin,extmax); %Marginalize
                    
                    lw1 = length(w1est); lw2 = length(w2est); lpr = length(prest); lw02 = length(w02est); lext = length(extest);%Rename length of marginalized vectors
                    sl = 5; sr = 5; %Sets how many data points to the left and right of the threshold to scan on the next loop;
                    
                    if l1 ==1
                        [errpr_l1, errw02_l1, errw2_l1, errw1_l1] = errorcheck(prBesti,prest,prestx,prBest,...
                            w02Besti,w02est,w02estx,w02Best,w2Besti,w2est,w2estx,w1Besti,w1est,w1estx,l1);
                    end
                    
                    if l1==2
                        [errpr_l2, errw02_l2, errw2_l2, errw1_l2] = errorcheck(prBesti,prest,prestx,prBest,...
                            w02Besti,w02est,w02estx,w02Best,w2Besti,w2est,w2estx,w1Besti,w1est,w1estx,l1);
                    end
                    
                    if l1 ==1
                        prestl1 = prest;
                        prestxl1 = prestx;
                        w02estl1 = w02est;
                        w02estxl1 = w02estx;
                        
                        w2estl1 = w2est;
                        w2estxl1 = w2estx;
                        w1estl1 = w1est;
                        w1estxl1 = w1estx;
                        
                        [w1min, w1max, error1_l1] =  param(w1est, thr, w1min, w1max, w1step, (sl+30)*0.002/w1step, (sr+30)*0.002/w1step);
                        [w2min, w2max, error2_l1] =  param(w2est, thr, w2min, w2max, w2step, (sl+10)*0.002/w2step, (sr+10)*0.002/w2step);
                        [prmin, prmax, error3_l1] =  param(prest, thr, prmin, prmax, fracstep, (sl+10)*0.002/fracstep, (sr+10)*0.002/fracstep);
                        [w02min, w02max, error4_l1] = param(w02est, thr, w02min, w02max, fracstep, sl*0.002/fracstep, sr*0.002/fracstep);
                        [extmin, extmax, error5_l1] = param(extest, thr, extmin, extmax, fracstep, sl*0.002/fracstep, sr*0.002/fracstep);
                        if isempty(w02max)
                            fprintf('j is %f',jind);
                            
                            
                        end
                    else
                        [~, ~, error1_l2] =  param(w1est, thr, w1min, w1max, w1step, (sl+30)*0.002/w1step, (sr+30)*0.002/w1step);
                        [~, ~, error2_l2] =  param(w2est, thr, w2min, w2max, w2step, (sl+10)*0.002/w2step, (sr+10)*0.002/w2step);
                        [~, ~, error3_l2] =  param(prest, thr, prmin, prmax, fracstep, sl*0.002/fracstep, sr*0.002/fracstep);
                        [~, ~, error4_l2] = param(w02est, thr, w02min, w02max, fracstep, sl*0.002/fracstep, sr*0.002/fracstep);
                        [~, ~, error5_l2] = param(extest, thr, extmin, extmax, fracstep, sl*0.002/fracstep, sr*0.002/fracstep);
                        
                    end
                end
                
                prBestmat(cindex,expt,jind) = prBest;
                w2Bestmat(cindex,expt,jind) = w2Best;
                w1Bestmat(cindex,expt,jind) = w1Best;
                
                output(cindex,expt,jind).prBest = prBest;
                output(cindex,expt,jind).w02Best = w02Best;
                output(cindex,expt,jind).w2Best = w2Best;
                output(cindex,expt,jind).w1Best = w1Best;
                
                output(cindex,expt,jind).prest = prest;
                output(cindex,expt,jind).prestx = prestx;
                output(cindex,expt,jind).w02est = w02est;
                output(cindex,expt,jind).w02estx = w02estx;
                
                output(cindex,expt,jind).w2est = w2est;
                output(cindex,expt,jind).w2estx = w2estx;
                output(cindex,expt,jind).w1est = w1est;
                output(cindex,expt,jind).w1estx = w1estx;
                
                output(cindex,expt,jind).error = [errpr_l1, errw02_l1, errw2_l1, errw1_l1, errpr_l2, errw02_l2, errw2_l2, errw1_l2];
                output(cindex,expt,jind).errparam = [error1_l1,error2_l1,error3_l1,error4_l1,error5_l1...
                    error1_l2,error2_l2,error3_l2,error4_l2,error5_l2,error6_l1,error6_l2,error7_l1,error7_l2];
                try
                    if input(cindex,expt,jind).save_posterior_flag
                        output(cindex,expt,jind).posterior = post;
                    end
                catch
                end
                
                output(cindex,expt,jind).prestl1 = prestl1;
                output(cindex,expt,jind).prestxl1 = prestxl1;
                output(cindex,expt,jind).w02estl1 = w02estl1;
                output(cindex,expt,jind).w02estxl1 = w02estxl1;
                output(cindex,expt,jind).w2estl1 = w2estl1;
                output(cindex,expt,jind).w2estxl1 = w2estxl1;
                output(cindex,expt,jind).w1estl1 = w1estl1;
                output(cindex,expt,jind).w1estxl1 = w1estxl1;
                
            end
        end
    end
    eltime = toc;
    scriptname = mfilename;
    save(outMatName,'output','prBestmat','w2Bestmat','w1Bestmat','eltime','scriptname');
    %outMatNamep = strcat(outMatName,'p');
    %save(outMatNamep,'poutput');
end

%                         prstep0 = prstep;  w02step0 = w02step; w2step0 = w2step; w1step0 = w1step;
%                         prmin0 = prmin; w02min0 = w02min; w1min0 = w1min; w2min0 =w2min;
%                         prmax0 = prmax; w02max0 = w02max; w1max0 = w1max; w2max0 =w2max;
