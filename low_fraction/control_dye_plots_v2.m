%This code plots the results of data_prep_cdyes_find_phofraction.m and 
%data_prep_cdyes_find_phofraction_changing_lifetimes.m data.
% Enter "no_int_life" for "key" to obtain results for changing photon fraction (fig
% 3b,c). You will need to enter the appropriate matout #s below
% 
%Enter "change_pho" to obtain results for changing photon number, holding 
%photon fraction fixed at 1/128 (fig 3d). You will need to enter the appropriate matout #s below
%
%Make appropriate filepath for matouts in line 47
clear; close all;

%Not Used
% change_ff_index_lowlife = {[5041,5058],[5059,5076],[5077,5094]};
% change_ff_index_medlife = {[5095,5112],[5113,5130],[5131,5148]};
% change_ff_index_highlife = {[5149,5166],[5167,5184],[5185,5202]};
% 
% change_ff_index_lowdata = {[5041,5058],[5095,5112],[5149,5166]};
% change_ff_index_meddata = {[5059,5076],[5113,5130],[5167,5184]};
% change_ff_index_highdata = {[5077,5094],[5131,5148],[5185,5202]};


%Matout #'s to be loaded in
change_phonum_index = {[5257,5264],[5265,5272],[5273,5280]};%Enter appropriate matout numbers here
change_ff_index_nointlife = {[5203,5220],[5221,5238],[5239,5256]};%Enter appropriate matout numbers here

indexes = {change_phonum_index,change_ff_index_nointlife};%, change_ff_index_lowlife...
%Not Used    %change_ff_index_medlife, change_ff_index_highlife,change_ff_index_lowdata...
%Not Used     %change_ff_index_meddata,change_ff_index_highdata};
keys = {'change_pho','nointlife'};%,'lowlife','medlife','highlife','lowdata','meddata','highdata'};
key2index = containers.Map(keys,indexes);

key = 'nointlife';% set this to 'nointlife' or 'change_pho'
color_palette = {[27,158,119]/255,[204,102,51]/255,[117,112,179]/255,[.6,.6,.6]}; %purple,orange,green,grey
indexcell = key2index(key);
loginset = 1; %Determines if the inset in the plot is set to log or if the main fig is log

%int_dye = {1.5e5,1.2e6,4.3e6};
int = 'blanked_int';
std_fitY= [];
std_fitX = [];

for iter_index_cell = 1:length(indexcell)
    for i = indexcell{iter_index_cell}(1):indexcell{iter_index_cell}(2)
        ind =i-indexcell{iter_index_cell}(1)+1;
        try
            nstr = strcat(pwd,'\matout\matout',num2str(i),'.mat');
            tempf=load(nstr,'-mat','output');
        catch exception
            fprintf('WARNING::: matout %3.0f does not exist\n',i);
        end

        cyclesmax = tempf.output(1,1,1).cyclesmax;
        output = tempf.output(:,:,:);
        %load in matout Max posterior info
        for j = 1:100
            post_meani(ind,j) = sum(output(j,1).prest'.*output(j,1).prestx);
            post_modei(ind,j) = output(j,1).prBest;
            post_stdi(ind,j) = sqrt(sum(output(j,1).prest'.*(output(j,1).prestx.^2)) ...
                - sum(output(j,1).prest'.*output(j,1).prestx).^2);
        end
    end
    
    %format as one vector
    mean_post_mode = mean(post_modei,2);
    std_post_mode = std(post_modei,0,2);
    mean_post_mean = mean(post_meani,2);
    std_post_mean = std(post_meani,0,2);
    post_std = mean(post_stdi,2);
    std_post_std = std(post_stdi,0,2);
    
    %%
    if strcmp(key,'change_pho')
        if strcmp(output(1,1,1).dataname(11:14),'1000')
            iratio = 1024;
            ti1 = sprintf('Estimated Short Lifetime Photon Fraction vs Photon Number');% \n %s control dye short frac = 1/%s',int, num2str(iratio,4));
            ti2 = sprintf('Std Dev vs Pho Number');% \n %s control dye short frac = 1/%s',int, num2str(iratio,4));
        else
            iratio = str2double(output(1,1,1).dataname(11:13));
            ti1 = sprintf('Estimated Short Lifetime Fraction vs Photon Number');% \n %s control dye short frac = 1/%s',int, num2str(iratio,3));
            ti2 = sprintf('Std Dev vs Pho Number');% \n %s control dye short frac = 1/%s',int, num2str(iratio,3));
        end
        npho = (50e6)./2.^(0:7); %Number of photons vector
        npho_guide = (50e6)./2.^(-1:9); %guideline vector
        
        %Photon fraction estimate vs photon number. Photon frac set to 1/128
        fig = figure(1); hold on;
        title(ti1);
        xlabel('Number of Photons'); % x-axis label
        ylabel('Photon Fraction Estimate'); % y-axis label
        ax = get(fig,'CurrentAxes');
        set(ax,'XScale','log','YScale','linear','XLim',[1e5 1e8],'YLim',[0 2e-2]);
        plot(npho_guide,(1/iratio)*ones(1,length(npho_guide)),'--','Color',color_palette{4});
        errorbar(npho,mean_post_mode,std_post_mode,'.','Color',color_palette{iter_index_cell}); %errorbar(X,Y,L,U)
        errorbar(npho,mean_post_mean,std_post_mean,'square','Color',color_palette{iter_index_cell});
        drawnow;
        
        %Plot standard deviation vs number of photons. Photon frac set to 1/128
        fig = figure(2);  hold on;
        ax = get(fig,'CurrentAxes');
        set(ax,'XScale', 'log', 'YScale', 'log','XLim',[1e5 1e8],'YLim',[5e-5 2e-3]);
        title(ti2);
        xlabel('Number of photons'); % x-axis label
        ylabel('Standard Deviation'); % y-axis label
        plot(npho,std_post_mode,'.','Color',color_palette{iter_index_cell});
        plot(npho,std_post_mean,'square','Color',color_palette{iter_index_cell});
        std_fitY = [std_fitY, std_post_mode];
        std_fitX = [std_fitX, npho];
        
        %Plots best-fit line to data
        if iter_index_cell==length(indexcell)
            fitmod = @(a,b,x) (a*x.^b);
            fresult = fit(reshape(std_fitX,[numel(std_fitX),1]),...
                reshape(std_fitY,[numel(std_fitY),1]),fitmod,'StartPoint',...
                [std_post_mode(1)*sqrt(npho(1)),0.5]);
            ci95 = confint(fresult,.95);
            fit_ci_plaw = (ci95(2,2)-ci95(1,2))/2;
            
            plot(npho_guide,fresult.a*npho_guide.^fresult.b,'--','Color',color_palette{4});
        end
        drawnow;
    end
    %%
    if ~strcmp(key,'change_pho')
        int_back = 1e3;
        ratio = 1./2.^(1:ind);
        % ratio = ratio/(1-int_back/int_dye{iter_index_cell}); Not Used
        ratio_plot_fit = 1./2.^(0:ind+3);
        fprintf('%s\n',output(1,1,1).dataname)
        
        %Plots measured photon faction vs actual photon fraction for 18
        %different photon fractions
        if iter_index_cell==1
            fig = figure(1); clf; hold on;
            ax1 = get(fig,'CurrentAxes');
            xlabel('Short Lifetime Photon Fraction'); ylabel('Estimated Short Lifetime Photon Fraction');
            ax2 = axes('position', [0.2 0.6 0.3 0.3]); hold on;
            if loginset
                set(ax1,'XLim',[0 0.55],'YLim',[0 0.55]);
                set(ax2,'XScale', 'log', 'YScale', 'log','XLim',[1e-6 1],'YLim',[1e-3 1]);
            else
                set(ax2,'XLim',[0 0.55],'YLim',[0 0.55]);
                set(ax1,'XScale', 'log', 'YScale', 'log','XLim',[1e-6 1],'YLim',[1e-6 1]);
            end
        end
        errorbar(ratio,mean_post_mode,std_post_mode,'Parent',ax1,'.',...
            'MarkerSize',20,'Color',color_palette{iter_index_cell});
        errorbar(ratio,mean_post_mean,std_post_mean,'Parent',ax1,'square',...
            'MarkerSize',15,'Color',color_palette{iter_index_cell}+.2);

%This was used when I was fitting X,Y with a line in real space with no weights.
%While a linear fit to X,Y worked well, it didn't work well for changes in
%lifetime fraction.

%         f =fit(ratio',mean_post_mode,'poly1')';
%         Y = f.p1.*ratio_plot_fit+f.p2;
        
        %Linear fit to the above data 
        fitpower = @(a,b,x) log(a*x+b);
        f =fit(ratio',log(mean_post_mode),fitpower, ...
            'StartPoint',[1,0],'Weights',log(1./std_post_mode));      
        Y = f.a.*ratio_plot_fit+f.b;
        ci95 = confint(f,.95);       
        fit_intercept(iter_index_cell) = f.b;
        fit_intercept_ci(iter_index_cell) = (ci95(2,2)-ci95(1,2))/2;
        
        fit_slope(iter_index_cell) = f.a;
        fit_slope_ci(iter_index_cell) = (ci95(2,1)-ci95(1,1))/2;
        
        plot(ratio_plot_fit,Y,'--','Color',color_palette{iter_index_cell},'Parent',ax1);
        plot(ratio_plot_fit,Y,'--','Color',color_palette{iter_index_cell},'Parent',ax2);
        errorbar(ratio,mean_post_mode,std_post_mode,'Parent',ax2,'.',...
            'MarkerSize',20,'Color',color_palette{iter_index_cell});
        errorbar(ratio,mean_post_mean,std_post_mean,'Parent',ax2,'square',...
            'MarkerSize',15,'Color',color_palette{iter_index_cell});
        drawnow; 
        
        %Calculate changes in photon fraction 
        for j = 1:ind-1
            s1 = post_modei(j,:);
            s2 = post_modei(j+1,:);
            s4 =[];
            for k = 1:cyclesmax-1
                s3 = s1 - circshift(s2,k,2);
                s4 = [s4 s3];
            end
            se_change_post_mode(j) = std(s4)/sqrt(cyclesmax);
            change_post_mode(j) = mean_post_mode(j)-mean_post_mode(j+1);
            if change_post_mode(j)<0
                fprintf('spot %3.0f has negativechange in mode of Photon fraction\n',j);
                % fech(j) =0;
                % fechse(j) =0;
            end
            
            t1 = post_meani(j,:);
            t2 = post_meani(j+1,:);
            t4 =[];
            for k = 1:cyclesmax-1
                t3 = t1 - circshift(s2,k,2);
                t4 = [t4 t3];
            end
            se_change_post_mean(j) = std(t4)/sqrt(cyclesmax);
            change_post_mean(j) = mean_post_mode(j)-mean_post_mode(j+1);
            if change_post_mode(j)<0
                fprintf('spot %3.0f has negativechange in mode of Photon fraction\n',j);
                % fech(j) =0;
                % fechse(j) =0;
            end
        end
         
        %Plot changes in photon fraction
        fig = figure(2); hold on;
        errorbar(ratio(2:end),change_post_mode,se_change_post_mode,'.','Color',color_palette{iter_index_cell});
        errorbar(ratio(2:end),change_post_mean,se_change_post_mean,'square','Color',color_palette{iter_index_cell});
        ax = get(fig,'CurrentAxes');
        set(ax,'XScale', 'log', 'YScale', 'log','XLim',[1e-6,1],'YLim',[1e-6,1] );
        xlabel('Changes in Short Lifetime Photon Fraction');
        ylabel('Estimated Changes in short lifetime photon fraction');
        
        %Originally we fit a line to log(y),log(x) (is equivalent to
        %fitting a power law to X,Y. But we decided on fitting
        %log(y),log(mx+b).
        
        %Fit changes in photon fraction
        fitpower = @(a,b,x) log(a*x+b);
        f_change =fit(ratio(2:end)',log(change_post_mode)',fitpower, ...
            'StartPoint',[1,0],'Weights',log(1./se_change_post_mode));
            %1./sqrt((se_change_post_mode.^2+se_change_post_mode.^2)));   

        %f_change
        ci95 = confint(f_change,.95);
        changes_slope(iter_index_cell) = f_change.a;
        changes_slope_ci(iter_index_cell) = (ci95(2,1)-ci95(1,1))/2;
        
        changes_inter(iter_index_cell) = f_change.b;
        changes_inter_ci(iter_index_cell) = (ci95(2,2)-ci95(1,2))/2; 
            
        Y_change = f_change.a.*ratio_plot_fit+f_change.b;
        plot(ratio_plot_fit,Y_change,'--','Color',color_palette{iter_index_cell});
        
        %cmode_fitY = [cmode_fitY, change_post_mode]; %cmode = change_post_mode
        %cmode_fitX = [cmode_fitX, ratio(2:end)];
        if iter_index_cell==length(indexcell)
        
%         f_change =fit(cmode_fitX',cmode_fitY','poly1');
%         Y_change = f_change.p1.*ratio_plot_fit+f_change.p2;
%         ci95 = confint(f_change,.95);
%         changes_fit_intercept(iter_index_cell) = f_change.p2;
%         changes_fit_intercept_ci(iter_index_cell) = (ci95(2,2)-ci95(1,2))/2;
%         
%         changes_fit_slope(iter_index_cell) = f_change.p1;
%         changes_fit_slope_ci(iter_index_cell) = (ci95(2,1)-ci95(1,1))/2;
%         plot(ratio_plot_fit,Y_change,'--','Color',color_palette{4});
        
%             legend('posterior-Mode (low int data)','posterior-Mean (low int data)',...
%                 'posterior-Mode (med int data)', 'posterior-Mean (med int data)',...
%                 'posterior-Mode (hi int data)', 'posterior-Mean (hi int data)');
        end
        drawnow;
    end
end
%%
%%



