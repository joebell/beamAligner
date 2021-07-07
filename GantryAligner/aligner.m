%%
% aligner.m
%
%   MATLAB class alignment tool for helping align the mesoscope gantry. It
%   uses a beamsplitter and two cameras to image the laser spot at
%   different distances while moving the gantry. At each gantry location
%   the spot images are fit to a Gaussian and the centers recorded.
%
%   This uses microscopeGantry.m to control the gantry.
%   Axes are numbered: 0: R, 1: X, 2: Y, 3: Z. 
%   All units are microns or degrees.
%
%   Methods to use:
%
%   .aligner() - Constructor.
%   .scanAxis(axisN, startLoc, endLoc, nStops, scanBack, startNearest)
%       Moves along axisN from startLoc to endLoc (um or deg.) making
%       nStops to take images. If scanBack is true then it takes an equal
%       number of images on the return trip. If startNearest is true the
%       gantry starts at the end of the sequence closest to the current
%       location.
%   .clearTrackData() - Clears the plot showing slopes at each scan.
%
% JSB 2/2017
%%
classdef aligner < handle
    
    properties
        nearCam
        farCam
        gui
        nearPos
        farPos
        nearSpotCenterMark
        farSpotCenterMark
        pixelSize = 5.3; % um
        xAxis
        yAxis
        gantry
        trackData
        axisNames = {'R','X','Y','Z'};
        axisUnits = {'deg.','{\mu}m','{\mu}m','{\mu}m'};
    end
    
    methods
        function aligner = aligner()
            
            % Settings for gantry and cameras.
            gantryPort = 'COM4';
            adaptorName = 'pointgrey';
            farCamN = 1;
            nearCamN = 2;
            
            aligner.farCam = videoinput(adaptorName,farCamN);
            aligner.nearCam = videoinput(adaptorName,nearCamN);
            
            set(aligner.farCam.source,...
                'BrightnessMode','Manual',...
                'ExposureMode','Manual',...
                'GainMode','Manual',...
                'ShutterMode','Manual',...
                'SharpnessMode','Manual');
            set(aligner.farCam.source,...
                'Gain',0,...
                'Shutter',22.963);
            
            set(aligner.nearCam.source,...
                'BrightnessMode','Manual',...
                'ExposureMode','Manual',...
                'GainMode','Manual',...
                'ShutterMode','Manual',...
                'SharpnessMode','Manual');
            set(aligner.nearCam.source,...
                'Gain',0,...
                'Shutter',10.068);
            
            set(aligner.nearCam, 'UserData', aligner);
            % set(aligner.nearCam, 'FramesAcquiredFcn', @calcNearCentroid); 
            set(aligner.nearCam, 'FramesAcquiredFcnCount', 1); 
            set(aligner.nearCam, 'FramesPerTrigger', 1);
            triggerconfig(aligner.nearCam, 'manual');
            
            set(aligner.farCam, 'UserData', aligner);
            % set(aligner.farCam, 'FramesAcquiredFcn', @calcFarCentroid); 
            set(aligner.farCam, 'FramesAcquiredFcnCount', 1); 
            set(aligner.farCam, 'FramesPerTrigger', 1);
            triggerconfig(aligner.farCam, 'manual');
            
            start(aligner.nearCam);
            start(aligner.farCam);
            
            aligner.gui.window = figure;
            set(gcf,'Position',[1540 424 1014 932]);
            vidRes = get(aligner.nearCam, 'VideoResolution');
            baseImage = zeros(vidRes(2),vidRes(1));
            aligner.xAxis = ([1:vidRes(1)] - vidRes(1)/2)*aligner.pixelSize;
            aligner.yAxis = ([1:vidRes(2)] - vidRes(2)/2)*aligner.pixelSize;
            
            aligner.gui.farImageAx = subplot(2,2,1);
            aligner.gui.farImage = image(aligner.xAxis, aligner.yAxis, baseImage);
            set(gca,'YDir','normal');
            axis image; hold on; axis on; 
            aligner.farSpotCenterMark = plot([xlim() NaN 0 0],[0 0 NaN ylim()],'r');
            title('Far Camera');
            
            aligner.gui.nearImageAx = subplot(2,2,2);
            aligner.gui.nearImage = image(aligner.xAxis, aligner.yAxis, baseImage); 
            set(gca,'YDir','normal');
            axis image; hold on; axis on; 
            aligner.nearSpotCenterMark = plot([xlim() NaN 0 0],[0 0 NaN ylim()],'r');
            title('Near Camera');
            
            aligner.gui.scanAx = subplot(2,2,3);
            plot(0,0);
            aligner.gui.trackAx = subplot(2,2,4);
            plot(0,0);
            
            aligner.trackData = [];
   
            aligner.startPreview();
            
            aligner.gantry = mesoscopeGantry(gantryPort);
            aligner.gantry.hwInfo();
            
        end
        
        function clearTrackData(al)
            al.trackData = [];
            axes(al.gui.trackAx); cla;
        end
        
        function saveFig(al, fileName)
            print(al.gui.window,fileName,'-dpdf');
            disp(['Saved as: ',fileName]);
        end
        
        function plotTrackData(al)
            
            axes(al.gui.trackAx); cla;
            markerList = {'bx:','ro:','b+-','rs-'};
            for fitN = 1:4
                plot(al.trackData(:,fitN),markerList{fitN}); hold on;
            end
            plot(xlim(),[0 0],'k--');
            ylabel('Slopes');
            xlabel('Scan iteration');
            legend('FarX','FarY','NearX','NearY');
            hold off;
        end
            
        
        function scanAxis(al, axN, startLoc, endLoc, nStops, scanBack, stNearest)
            
            axes(al.gui.scanAx); cla;
            locs = linspace(startLoc, endLoc, nStops);
            
            % If scanBack, scan back across the defined path in the 
            % opposite direction.
            if scanBack
                locs = [locs, fliplr(locs)];
            end
            
            % If stNearest, flip the scan order to start at the nearest
            % point to the current position to save travel time.
            if stNearest
                cp = al.gantry.getPos(axN);
                if abs(cp - locs(end)) < abs(cp - locs(1))
                    locs = fliplr(locs);
                end
            end
            
            
            for stopN = 1:length(locs)
                al.gantry.goto(axN, locs(stopN));
                al.gantry.waitForMove(); pause(.5);
                actLocs(stopN) = al.gantry.getPos(axN);
                [fx,fy] = al.calcFarCentroid();
                [nx,ny] = al.calcNearCentroid();
                spotCoords(stopN,:) = [fx,fy,nx,ny];
                axes(al.gui.scanAx);
                markerList = {'bx:','ro:','b+-','rs-'};
                for plotN = 1:4
                    h(plotN) = plot(actLocs,spotCoords(:,plotN),markerList{plotN}); hold on;  
                end  
                legend(h, 'FarX','FarY','NearX','NearY');
                title(['Scan along axis: ', al.axisNames{axN+1}]);
                xlabel(['Axis travel (', al.axisUnits{axN+1},')']);
                ylabel('Beam center ({\mu}m)');
            end
            disp('.');
            legend('off');
            
 
            slopes = zeros(1,4);
            for fitN = 1:4
                f{fitN} = fit(actLocs(:), spotCoords(:,fitN),'poly1');
                slopes(fitN) = f{fitN}.p1;
                plot(f{fitN},'k--'); 
            end
            legend(h, 'FarX','FarY','NearX','NearY');
            xlabel(['Axis travel (', al.axisUnits{axN+1},')']);
            ylabel('Beam center ({\mu}m)');
            hold off;
            
            al.trackData = cat(1,al.trackData,slopes);
            al.plotTrackData();
            title(['Aligning axis: ', al.axisNames{axN+1}]);
        end
                
        
        function startPreview(al)           
            preview(al.farCam, al.gui.farImage);
            preview(al.nearCam, al.gui.nearImage);
            
            axes(al.gui.nearImageAx); axis on;
            axes(al.gui.farImageAx); axis on;
        end
        
        function [xo,yo] = calcNearCentroid(al)

            thresh = .05;
            [X,Y] = meshgrid(al.xAxis,al.yAxis);
            trigger(al.nearCam); pause(.1);
            f = double(getdata(al.nearCam,1))./255;
            start(al.nearCam);
            
            decimate = true;
            if decimate
                decFact = 8;
                xDecIX = [1:decFact:length(al.xAxis)];
                yDecIX = [1:decFact:length(al.yAxis)];

                f = f(yDecIX,xDecIX);
                X = X(yDecIX,xDecIX);
                Y = Y(yDecIX,xDecIX);
            end

            % disp('Fitting gaussian...');
            fprintf('.');
            ft = fittype('M * exp(-(1/(2*(a*1000)^2))*(X - xo*1000)^2 + (1/(2*(b*1000)^2))*(X - xo*1000)*(Y - yo*1000) - (1/(2*(c*1000)^2))*(Y-yo*1000)^2)',...
                        'independent',{'X','Y'},...
                        'dependent',{'f'},...
                        'coefficients',{'M','a','b','c','xo','yo'});
            opts = fitoptions(ft);
            opts.TolX = 0.0001;
            opts.TolFun = .001;
            opts.DiffMaxChange = 10;
            opts.DiffMinChange = .1;
            opts.Start = [.8,  1,  2,  1, 0, 0];
            opts.Lower = [.2, .1, .1, .1, al.xAxis(1)/1000, al.yAxis(1)/1000];
            opts.Upper = [1.2,  3,  3,  3, al.xAxis(end)/1000, al.yAxis(end)/1000]; 
            opts.Display = 'off'; % 'iter' 'off'
            fo = fit([X(:),Y(:)],f(:), ft, opts);
            
            xo = fo.xo*1000;
            yo = fo.yo*1000;
            set(al.nearSpotCenterMark,'XData',[al.xAxis(1) al.xAxis(end) NaN xo xo]);
            set(al.nearSpotCenterMark,'YData',[yo yo NaN al.yAxis(1) al.yAxis(end)]);
%            disp(sprintf('Fit to [%.1f, %.1f]',[xo,yo]));
            
%             figure();
%             subplot(1,2,1);
%             image(al.xAxis, al.yAxis, f,'CDataMapping','scaled'); 
%             axis image;
%             set(gca,'YDir','normal');
%             subplot(1,2,2);
%             plot(fo, 'Style','Contour');  axis image;

        end

       function [xo, yo] = calcFarCentroid(al)

            thresh = .05;
            [X,Y] = meshgrid(al.xAxis,al.yAxis);
            trigger(al.farCam); pause(.1);
            f = double(getdata(al.farCam,1))./255;
            start(al.farCam);
            
            decimate = true;
            if decimate
                decFact = 8;
                xDecIX = [1:decFact:length(al.xAxis)];
                yDecIX = [1:decFact:length(al.yAxis)];

                f = f(yDecIX,xDecIX);
                X = X(yDecIX,xDecIX);
                Y = Y(yDecIX,xDecIX);
            end

%             disp('Fitting gaussian...');
            fprintf('.');
            ft = fittype('M * exp(-(1/(2*(a*1000)^2))*(X - xo*1000)^2 + (1/(2*(b*1000)^2))*(X - xo*1000)*(Y - yo*1000) - (1/(2*(c*1000)^2))*(Y-yo*1000)^2)',...
                        'independent',{'X','Y'},...
                        'dependent',{'f'},...
                        'coefficients',{'M','a','b','c','xo','yo'});
            opts = fitoptions(ft);
            opts.TolX = 0.0001;
            opts.TolFun = .01;
            opts.DiffMaxChange = 10;
            opts.DiffMinChange = .1;
            opts.Start = [.8,  1,  2,  1, 0, 0];
            opts.Lower = [.2, .1, .1, .1, al.xAxis(1)/1000, al.yAxis(1)/1000];
            opts.Upper = [1.2,  3,  3,  3, al.xAxis(end)/1000, al.yAxis(end)/1000]; 
            opts.Display = 'off'; % 'iter'
            fo = fit([X(:),Y(:)],f(:), ft, opts);
            
            xo = fo.xo*1000;
            yo = fo.yo*1000;
            set(al.farSpotCenterMark,'XData',[al.xAxis(1) al.xAxis(end) NaN xo xo]);
            set(al.farSpotCenterMark,'YData',[yo yo NaN al.yAxis(1) al.yAxis(end)]);
%            disp(sprintf('Fit to [%.1f, %.1f]',[xo,yo]));
            
%             figure();
%             subplot(1,2,1);
%             image(al.xAxis, al.yAxis, f,'CDataMapping','scaled'); 
%             axis image;
%             set(gca,'YDir','normal');
%             subplot(1,2,2);
%             plot(fo, 'Style','Contour');  axis image;

        end
        
    end
    
end


    