%% Load file
clear all;

%root_path = 'C:\Users\Virginia Casasnovas\Documents\Virginia\Data\IO\';
root_path = 'C:\Users\Virginia Casasnovas\Documents\Virginia\Data\MINISCOPES\HeadFreeTreadmillMiniscope\';
experiment_folder = '20190510 - miniscopes adaptation RF';
imaging = 1;

filesep = '\';

addpath(genpath(root_path));

% Behavior
tracking_main = 'TM TRACKING FILES';
processed_main = 'TM PROCESSED FILES';
output_main  = 'TM GAIT CODE OUTPUT AND PLOTS';

% Imaging
raw_main = 'TM RAW FILES';
registered_main = 'TM PROCESSED IMAGING FILES';
segmented_main = 'TM SEGMENTED IMAGING FILES';

tracking_path = [root_path,tracking_main,filesep,experiment_folder,filesep]; % Folder with tracking files (.mat)
processed_path = [root_path,processed_main,filesep,experiment_folder,filesep]; % Folder with processed tracking files (.mat)
output_stride_folder = [root_path,output_main,filesep,experiment_folder,'\GaitParametersOutput\'];
output_trial_folder = [root_path,output_main,filesep,experiment_folder,'\GroupedData\'];

raw_path = [root_path,raw_main,filesep,experiment_folder,filesep];
registered_path = [root_path,registered_main,filesep,experiment_folder,filesep];
segmented_path = [root_path,segmented_main,filesep,experiment_folder,filesep];

params.gait = {'stance_length', 'stance_length_rel_body', 'stance_length_rel_body_and_belt', 'stance_speed', 'stance_duration', 'swing_onset_x_rel'...
    'swing_length', 'swing_length_rel_body', 'swing_length_rel_body_and_belt', 'swing_speed', 'swing_duration', 'stance_onset_x_rel', ...
    'cadence', 'duty_factor', 'double_support', 'stride_duration', 'step_length', 'coo_body', 'body_speed', 'body_speed_rel', 'stride_length', ...
    'stance_phase'};

params.trial_stride = {'trial_num','trial_type','speed_L','speed_R'};
params.trial_trial = {'trial_nr','is_tied','speed_L','speed_R'};

params.raw_paws = {'paws_x','paws_y','paws_z','paw_center_x','paw_center_y','paws_x_rel','paws_y_rel'};

%% TD
dir_tracking = dir([tracking_path]);
folder_tracking = dir_tracking([dir_tracking.isdir]);

mouse_folder = {};
for i = 3:length(folder_tracking)
    mouse_folder{i-2} = folder_tracking(i).name;
end

TD = struct();

for imouse = 1:length(mouse_folder)
    
    tic;
    
    TD(imouse).mouse = mouse_folder{imouse};
    
    for iparam = 1:length(params.trial_stride)
        param_path = [output_stride_folder,mouse_folder{imouse},filesep,'classic',filesep,params.trial_stride{iparam},'.mat'];
        param_data = load(param_path);
        TD(imouse).output.stride.(params.trial_stride{iparam}) = param_data.data_var;
    end
    
    for iparam = 1:length(params.trial_trial)
        param_path_trial = [output_trial_folder,'GroupedOutput.mat'];
        param_data_trial = load(param_path_trial);
        
        if strcmp(params.trial_trial{iparam},'trial_nr')
            TD(imouse).output.trial.trial_num = param_data_trial.output.trials.(params.trial_trial{iparam});
        else
            TD(imouse).output.trial.(params.trial_trial{iparam}) = param_data_trial.output.trials.(params.trial_trial{iparam});
        end
    end
    TD(imouse).output.trial.trial_type = cell(length(TD(imouse).output.trial.trial_num),1);
    TD(imouse).output.trial.trial_type([TD(imouse).output.trial.is_tied]) = {'tied'};
    TD(imouse).output.trial.trial_type(~[TD(imouse).output.trial.is_tied]) = {'split'};
    
    TD(imouse).output.trial = rmfield(TD(imouse).output.trial,'is_tied');
    TD(imouse).output.trial = orderfields(TD(imouse).output.trial,[1,4,2:3]);
    
    for iparam = 1:length(params.gait)
        param_path = [output_stride_folder,mouse_folder{imouse},filesep,'classic',filesep,params.gait{iparam},'.mat'];
        param_data = load(param_path);
        TD(imouse).output.stride.(params.gait{iparam}) = param_data.data_var;
        
        param_path_trial = [output_trial_folder,'GroupedOutput.mat'];
        param_data_trial = load(param_path_trial);
        TD(imouse).output.trial.sym.(params.gait{iparam}) = cell2mat(param_data_trial.output.regular.sym.(params.gait{iparam})(imouse,:));
        TD(imouse).output.trial.(params.gait{iparam}) = param_data_trial.output.regular.vars.(params.gait{iparam})(:,:,imouse);
    end
    
    processed_file = dir([processed_path,mouse_folder{imouse},'_*.mat']);
    kproc = 0;
    for iproc = 1:length(processed_file)
        processed_name = processed_file(iproc).name;
        processed_data = load([processed_path,processed_name]);
        
        if ~isempty(processed_data.strides{1})
            kproc = kproc+1;
            TD(imouse).tracking(kproc).trial_num = processed_data.trial_data.trial_nr;
            TD(imouse).tracking(kproc).trial_type = processed_data.trial_data.trial_type;
            TD(imouse).tracking(kproc).speed_R = processed_data.trial_data.speed_R;
            TD(imouse).tracking(kproc).speed_L = processed_data.trial_data.speed_L;
            
            TD(imouse).tracking(kproc).time = processed_data.trial_data.timesteps;
            TD(imouse).tracking(kproc).final_tracks = processed_data.final_tracks;
            
            for iparam = 1:length(params.raw_paws)
                TD(imouse).tracking(kproc).raw_paws.(params.raw_paws{iparam}) = processed_data.trial_data.(params.raw_paws{iparam});
            end
            
            TD(imouse).tracking(kproc).stride_fr = processed_data.strides;
            TD(imouse).tracking(kproc).st_sw_frames = get_st_sw_frames(TD(imouse).tracking(kproc));
            [TD(imouse).tracking(kproc).loco_frame,TD(imouse).tracking(kproc).loco_time,TD(imouse).tracking(kproc).loco_step] = loco_epochs(TD(imouse).tracking(kproc)); % Extracting locomotion epochs
        end
    end
    
    if imaging
        segmented_file =  rdir([segmented_path,mouse_folder{imouse},filesep,'*_Seg.mat']);
        
        kseg = 0;
        for iseg = 1:length(segmented_file)
            imaging_data = load(segmented_file(iseg).name,'cn');
            if ~isempty(imaging_data.cn.intensity)
                kseg = kseg+1;
                trial_str = strsplit(segmented_file(iseg).name,{'_','.'});
                trial = str2num(trial_str{end-3});
                
                TD(imouse).imaging(kseg).trial_num = trial;
                
                % Final cell segmentation signals saved in neurons_trialnumber.mat file
                TD(imouse).imaging(kseg).intensity = imaging_data.cn.intensity;
                TD(imouse).imaging(kseg).intensity_bkg = imaging_data.cn.intensity_bkg;
                TD(imouse).imaging(kseg).spike = imaging_data.cn.spikes;
                TD(imouse).imaging(kseg).mask = imaging_data.cn.mask;
                
                if ~isfield(imaging_data.cn,'time')
                    timestamp = importdata([raw_path,mouse_folder{imouse},'\miniscope\T',num2str(trial),'\timestamp.dat']); % Loading imaging timestamp file
                    TD(imouse).imaging(kseg).time = timestamp.data(:,3)/1000; % sysClock contains timestamps of miniscope video
                else
                    TD(imouse).imaging(kseg).time = imaging_data.cn.time;
                end
            end
        end
        
        TD(imouse) = match_img_tacking_frames(TD(imouse));
        TD(imouse) = match_loco_frames(TD(imouse));
        % TD(imouse) = loco_spike_count(TD(imouse));
    end
    telapsed = toc;
    fprintf('TD for %s processed in %1.2f sec.\n',mouse_folder{imouse},telapsed)
end

%% Save TD
if ~exist([root_path,'TM TRIAL DATA',filesep,experiment_folder,filesep],'dir')
    mkdir([root_path,'TM TRIAL DATA',filesep,experiment_folder,filesep]);
    save([root_path,'TM TRIAL DATA',filesep,experiment_folder,filesep,'TD.mat'],'TD');
else
    resave = input(['\nOverwrite TD for ',experiment_folder,'? [y/n] '],'s');
    if strcmp(resave,'y')
        save([root_path,'TM TRIAL DATA',filesep,experiment_folder,filesep,'TD.mat'],'TD');
    end
end

%% More analysis
% load([root_path,'TM TRIAL DATA',filesep,experiment_folder,filesep,'TD.mat']);

for imouse = 1:length(TD)
    %     TD(imouse).tracking = stride_binning(TD(imouse).tracking,'final_tracks',10);
    %     TD(imouse).imaging = norm_intensity(TD(imouse).imaging);
    TD(imouse).imaging = get_param_imaging(TD(imouse).imaging);
    
    nbins = 10; % Number of bins for stride modulation
    signal = 'int_bkg_norm';
    TD(imouse) = stride_modulation(TD(imouse),nbins,signal); % Stride modulation analysis
    TD(imouse).imaging = mean_stride_intensity(TD(imouse).imaging);
    TD(imouse) = stance_phase_intensity(TD(imouse));
    
    TD(imouse).tracking = get_body_kin(TD(imouse).tracking);
    
    TD(imouse).output.trial = assign_col_trial(TD(imouse).output.trial);
    TD(imouse).output.stride = assign_col_trial(TD(imouse).output.stride);
end

paw_lab = {'FR','HR','FL','HL'};
paw_col = {'r','m','b','c'};
sym_lab = {'Front','Hind'};

ncells = size(TD(imouse).imaging(1).intensity,2);
purple = [76, 0, 153]/255;
lilliac = [204, 153, 253]/255;
cell_col = [linspace(lilliac(1),purple(1),ncells)', linspace(lilliac(2),purple(2),ncells)', linspace(lilliac(3),purple(3),ncells)'];

%% Figures
%% Body position and intensity
tri = 2;
imouse = 1;
tri_img = find([TD(imouse).imaging.trial_num]==TD(imouse).tracking(tri).trial_num);
figure;
body_signal = (TD(imouse).tracking(tri).body_pos-mean(TD(imouse).tracking(tri).body_pos))/std(TD(imouse).tracking(tri).body_pos);
% plot(TD(imouse).tracking(tri).time, squeeze((TD(imouse).tracking(tri).final_tracks(1,1:4,:))));
hold on;
% plot(TD(imouse).tracking(tri).time, body_signal)
% plot(TD(imouse).tracking(tri).time(1:end-1), (TD(imouse).tracking(tri).body_vel-mean(TD(imouse).tracking(tri).body_vel))/std(TD(imouse).tracking(tri).body_vel))
hold on
plot(TD(imouse).tracking(tri).time(1:end-2), (TD(imouse).tracking(tri).body_acc-mean(TD(imouse).tracking(tri).body_acc))/std(TD(imouse).tracking(tri).body_acc))
hold on
plot(TD(imouse).imaging(tri_img).time, TD(imouse).imaging(tri_img).int_norm(:,3));

title(['L: ',num2str(TD(imouse).tracking(tri).speed_L),'; R: ',num2str(TD(imouse).tracking(tri).speed_R),' m/s'])
legend({'body position','cell intensity'})
xlabel('time (s)'); ylabel('signal (au)');

%% Stride modulation
plt_cell = 0;
plt_mean_cell = 1;
for imouse = 1:length(TD)
    img_trial = sort([TD(imouse).imaging.trial_num]);
    for itrial = img_trial
        plot_stride_md(TD(imouse),itrial,plt_cell,plt_mean_cell)
    end
end

%% Intensity
cmap = colormap(winter(5));
for imouse = 1:length(TD)
    img_trial = sort([TD(imouse).imaging.trial_num]);
    for itrial = 1:length(img_trial)
        cum_int = 0;
        figure;
        %         plot(TD(imouse).imaging(itrial).time,TD(imouse).imaging(itrial).int_norm(:,1:3),'r')
        for icell = 1:5
            plot(TD(imouse).imaging(itrial).time,TD(imouse).imaging(itrial).int_bkg_norm(:,icell)+cum_int,'Color',cmap(icell,:))
            hold on;
            cum_int = cum_int + max(TD(imouse).imaging(itrial).int_bkg_norm(:,icell));
        end
    end
end

%% Intensity
for imouse = 1:length(TD)
    img_trial = sort([TD(imouse).imaging.trial_num]);
    for itrial = 1:length(img_trial)
        figure;
        plot(TD(imouse).imaging(itrial).time,TD(imouse).imaging(itrial).intensity(:,1),'r')
        hold on;
        plot(TD(imouse).imaging(itrial).time,TD(imouse).imaging(itrial).intensity(:,1)-prctile(TD(imouse).imaging(itrial).intensity(:,1),25),'b')
        plot(TD(imouse).imaging(itrial).time,TD(imouse).imaging(itrial).intensity(:,1)-mean(TD(imouse).imaging(itrial).intensity(:,1)),'m')
        plot(TD(imouse).imaging(itrial).time,TD(imouse).imaging(itrial).intensity_bkg(:,1),'g')
        
    end
end

%% Average intensity
signal = 'area_int_bkg_norm';
for imouse = 1:length(TD)
    figure;
    img_trial = sort([TD(imouse).imaging.trial_num]);
    for itrial = 1:length(img_trial)
        plot(TD(imouse).imaging(itrial).trial_num,TD(imouse).imaging(itrial).(signal),'Marker','o','MarkerEdgeColor',lilliac)
        hold on;
        plot(TD(imouse).imaging(itrial).trial_num,mean(TD(imouse).imaging(itrial).(signal)),'ko','MarkerFaceColor',purple)
        errorbar(TD(imouse).imaging(itrial).trial_num,mean(TD(imouse).imaging(itrial).(signal)),std(TD(imouse).imaging(itrial).(signal))/sqrt(ncells),'Color',purple)
    end
    ax = gca;
    ax.XTick = img_trial(1):img_trial(end);
    xlabel('trial num');
    ylabel('area \DeltaF/F [-]');
end

%% Speed grouped
trk_params = {'stride_bins_mean'};
img_params = {'img_bins_mean','img_bins_mean_cell','mean_int_norm','area_int_norm','mean_int_bkg_norm','area_int_bkg_norm'};
out_params = {};

GS = struct();
group_speed = struct();
for imouse = 1:length(TD)
    [spd,trial_spd] = get_unique_speed(TD(imouse).tracking);
    
    GS(imouse).group_speed = group_by_speed(TD(imouse).tracking,[],spd,trial_spd,trk_params);
    GS(imouse).group_speed = group_by_speed(TD(imouse).imaging,GS(imouse).group_speed,spd,trial_spd,img_params);
    
    TD(imouse).output = assign_col_speed(GS(imouse).group_speed,TD(imouse).output);
end

%% Plot stride modulation
plt_cell = 1;
plt_mean_cell = 1;
for imouse = 1:length(GS)
    plot_stride_md_spd(GS(imouse).group_speed,plt_cell,plt_mean_cell);
end

%% Plot speed modulation for mean and area intensity
signal = 'int_bkg_norm';
for imouse = 1:length(GS)
    plot_intensity_spd(GS(imouse).group_speed,signal);
end

%% Plot intensity vs gait parameter
% based on intensity per stride data
params_gait = {'step_length', 'coo_body', 'double_support', 'body_speed', 'body_speed_rel'};

plt_stride = 0; plt_trial = 1;
col_spd = isempty(strfind(experiment_folder,'adaptation'));
for iparam = 1:length(params_gait)
    for imouse = 1:length(TD)
        plot_param_intensity(TD(imouse),params_gait{iparam},plt_stride,plt_trial,col_spd)
    end
end

%% Plot intensity vs gait symmetry parameter
params_gait = {'step_length', 'coo_body', 'double_support','stance_phase'};

col_spd = isempty(strfind(experiment_folder,'adaptation'));
for iparam = 1:length(params_gait)
    for imouse = 1:length(TD)
        plot_param_intensity_sym(TD(imouse),params_gait{iparam},col_spd)
    end
end

