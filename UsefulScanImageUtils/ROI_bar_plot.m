classdef ROI_bar_plot < handle
    % Make bar plots of mean intensity in each ROI
    %
    % This class adds listeners to ScanImage so you don't need to manually
    % add stuff to the user function interface. 
    %
    % Known issues:
    % Works in data from the first displayed channel but uses the look up table
    % from channel 1 always
    %
    % Instructions
    % Start ScanImage
    % Run ROI_bar_plot: R=ROI_bar_plot
    % Then press Grab (or maybe Focus) in ScanImage
    %
    % To enable normalised mode do:
    % R.norm=true;
    %
    % To disable it:
    % R.norm=false;
    %
    % Re-enabling it will reset the value by which it is normalising.
    % 
    % Closing the ROI bar figure shuts down the class and detachs the listeners

    properties
       showMeans = true % set to false to not show mean values
       norm=false; %normalize if true
       meanROIsSaved
    end

    properties (Hidden)
       hSI % ScanImage API
       hFig % The figure window
       hAx % the axes we plot into
       hBar % The bar object
       figTagName='ROI bar plot';
       listeners={};
       meanText
    end
    
    methods
        function obj = ROI_bar_plot
            % Connect to ScanImage API 
            scanimageObjectName='hSI';
            W = evalin('base','whos');
            SIexists = ismember(scanimageObjectName,{W.name});
            if ~SIexists
                fprintf('ScanImage not started.\n')
                delete(obj)
                return
            end


            API = evalin('base',scanimageObjectName); % get hSI from the base workspace
            if ~isa(API,'scanimage.SI')
                fprintf('hSI is not a ScanImage object.\n')
                delete(obj)
                return
            end

            obj.hSI=API;

            % Add listeners
            obj.listeners{end+1}=addlistener(obj.hSI.hUserFunctions, 'frameAcquired', @obj.updateBars);
            %obj.listeners{end+1}=addlistener(obj.hSI.hUserFunctions, 'focusStart', @obj.setUpPlot);
            obj.listeners{end+1}=addlistener(obj.hSI.hUserFunctions, 'acqModeStart', @obj.setUpPlot);


            % Only create a plot window if one does not already exist 
            % (want to avoid writing into existing windows that are doing other stuff)
            obj.hFig = findobj(0, 'Tag', obj.figTagName);
            if isempty(obj.hFig)
                %If the figure does not exist, make it
                obj.hFig = figure;
                set(obj.hFig, 'Tag', obj.figTagName, 'Name', 'ROI bar plot')
            end

            %Focus on the figure and clear it
            figure(obj.hFig)
            clf
            obj.hAx = cla;

            obj.hFig.CloseRequestFcn = @obj.windowCloseFcn;

        end % Constructor

        function delete(obj)
            obj.hSI=[];
            cellfun(@delete,obj.listeners)
            obj.hFig.delete %Closes the plot window
        end % Destructor

        function windowCloseFcn(obj,~,~)
            % This runs when the user closes the figure window.
            fprintf('Shutting down ROI_bar_plot.\n')
            obj.delete % simply call the destructor
       end %close windowCloseFcn


       function setUpPlot(obj,~,~)
            % Runs on 'focusStart'

            %Focus on the figure window
            figure(obj.hFig)

            numRois = numel(obj.hSI.hRoiManager.roiGroupMroi.rois);
            meanRois = zeros(numRois+1,1);
            obj.hBar = bar(meanRois,'parent',obj.hAx); %plot into our figure window
            yLimit = obj.hSI.hChannels.channelLUT{1};
            ylim(yLimit);

            for ii = numRois+1:-1:1
                obj.meanText{ii}=text(ii,double(yLimit(2))*0.9,'', ...
                    'HorizontalAlignment','center', 'FontSize', 13, 'Color',[.9 .9 .9]);
            end
            set(obj.meanText{end}, 'Color', 'r')            
            set(gca,'Color', 'k')

       end

        function updateBars(obj,~,~)
            % Runs on 'frameAcquired'
            numRois = numel(obj.hSI.hRoiManager.roiGroupMroi.rois);
            meanRois = zeros(numRois+1,1);
            numRSDB = length(obj.hSI.hDisplay.rollingStripeDataBuffer);
            numRD = length(obj.hSI.hDisplay.rollingStripeDataBuffer{1}{1}.roiData);

            for iRSDB = 1:numRSDB
                 for iRD = 1:numRD %Loop over ROIs
                    iRoi = (iRSDB-1)*numRD + iRD;
                    tROIdata = obj.hSI.hDisplay.rollingStripeDataBuffer{iRSDB}{1}.roiData;
                    if isempty(tROIdata) %On the first frame this may be empty
                        continue
                    end
                    meanRois(iRoi) = mean(tROIdata{iRD}.imageData{1}{1}(:))/obj.hSI.hDisplay.displayRollingAverageFactor;
                 end
            end

            meanRois(end) = mean(meanRois(1:numRois));

            if obj.norm
                if isempty(obj.meanROIsSaved)
                    obj.meanROIsSaved = meanRois;
                end
                meanRois = meanRois./obj.meanROIsSaved;
                yLimit = [.25, 1.5];
                ch = get(gca,'Children');
                for i = 1:numRois+1
                    set(ch(i),'Position',[i double(yLimit(2))*0.9])
                    set(ch(i),'String',sprintf('%.3f',meanRois(i)))
                end
             else
                yLimit = obj.hSI.hChannels.channelLUT{1};
                obj.meanROIsSaved = [];

                if obj.showMeans
                    for ii = 1:length(obj.meanText)
                        yPos = meanRois(ii)*1.2;
                        %yPos=double(yLimit(2))*0.9; %Fixed ypos
                        set(obj.meanText{ii},'Position',[ii yPos], ...
                            'String',sprintf('%.0f',meanRois(ii)))
                    end
                end
            end

             set(obj.hBar,'ydata',meanRois);
             ylim(yLimit);
             %set(get(hBar,'Parent'),'ylim',(obj.hSI.hChannels.channelLUT{1}));
             %sprintf('%.2f', meanRois(end))
       end % updateBars

    end %methods
end % classdef