%%
% mesoscopeGantry.m
%
%   MATLAB class for controlling the Thor mesoscope gantry. Axes are
%   numbered: 0: R, 1: X, 2: Y, 3: Z. All units are microns or degrees.
%
%   Methods to use:
%
%   .microscopeGantry(port) - 
%   .hwInfo()               - Reports info on the hardware.
%   .getPos()               - Gets and returns the current encoder values 
%                             for all axes.
%   .getPos(listOfAxes)     - Gets and returns the encoder values for some 
%                             enumerated axes.
%   .goto(pos)              - Moves to a position specified in 4 axes.
%   .goto(listOfAxes, pos)  - Moves to a position on specified some axes.
%   .waitForMove()          - Blocks execution until the move is done.
%
% JSB 2/2017
%%
classdef mesoscopeGantry < handle
    
    properties
        portName
        serialPort
        axScale = [.00012, .5, .5, .1]; 
        currentAxis
        currentPos
        axisMoving
        lastCommand
    end
    
    methods
        
        %% Constructor, takes a serial port name eg. 'COM4'
        function mesoscopeGantry = mesoscopeGantry(portName)
            mesoscopeGantry.portName = portName;
            mesoscopeGantry.openPort();
        end
        
        
        %% Reports info on the hardware
        function hwInfo(g)
             g.sendBytes(['05';'00';'00';'00';'01';'01']);
        end
        
        
        %% Gets the encoder positions. Can be used as:
        %   positions = g.getPos()
        %   positions = g.getPos(listOfAxes)
        function pos = getPos(g, varargin)
            if (nargin == 1)
                % Check the all encoders for the current position
                for ax = [0:3]
                    g.GET_ENC_STATUS(ax);
                    pause(.05);
                end
                pos = g.currentPos;
            elseif (nargin == 2)
                % Check just the enumerated axes
                varargin{1};
                for ax = varargin{1}
                    g.GET_ENC_STATUS(ax);
                    pause(.05);
                end
                pos = g.currentPos(varargin{1}+1);
            end
        end
        
        
        %% Move the gantry to a location. Can be used as:
        %  g.goto(targets);        % Targets of a 4-vector of [R,X,Y,Z]
        %  g.goto(axes, targets);  % Axes is a list of axes indexes,
        %                          %   then targets is the same size.
        function goto(g, varargin)
            
            if (nargin == 2)
                axes = [0:3];
                targets = varargin{1};
            elseif (nargin == 3)
                axes = varargin{1};
                targets = varargin{2};
            end
        
            for axN = 1:length(axes)
                g.MOVE_ABSOLUTE(axes(axN), targets(axN));
                pause(.05);
            end
        end
        
        
        %% Blocks execution until the gantry is done moving. This also 
        % also ensures that g.currentPos is up to date.
        function waitForMove(g)
            needsCheck = true;
            while (needsCheck)
                for ax = [0:3]
                    g.GET_MOTOR_STATUS(ax);
                    pause(.05);
                end
                if sum(g.axisMoving) > 0
                    needsCheck = true;
                else
                    needsCheck = false;
                end
            end
        end
        
        
        
        
        
        
        
        %% Open the serial port
        function openPort(g)
            
            g.serialPort = serial(g.portName);
            
            g.serialPort.BaudRate = 115200;
            g.serialPort.BytesAvailableFcn = @(obj, event) g.readPort(obj, event);
            g.serialPort.BytesAvailableFcnMode = 'byte';
            g.serialPort.BytesAvailableFcnCount = 1;
            g.serialPort.Terminator = 'CR';

            fopen(g.serialPort);       
        end
        
        % Send bytes on the port, save the most recent command to try to 
        % recover from problems.
        function sendBytes(g, data)
            fwrite(g.serialPort, uint8(hex2dec(data)));
            g.lastCommand = data;
        end
        
        % Callback function for reading the port
        function readPort(g, obj, event)
        
            serialPort = obj;

            % As long as there are still bytes to be read in the buffer...
            while (serialPort.BytesAvailable > 0)
                % Read in the bytes and parse them.
                bytesIn = fread(serialPort,serialPort.BytesAvailable); 
                g.parseBytes(bytesIn);
            end
      
        end
        
       
        %% Helper functions
        function GET_MOTOR_STATUS(g, chID)
            chStr = sprintf('%02x',chID);
            g.sendBytes(['80';'04';chStr;'00';'01';'01']);
        end
        function GET_ENC_STATUS(g, chID)
            chStr = sprintf('%02x',chID);
            g.sendBytes(['0A';'04';chStr;'00';'01';'01']);
            g.currentAxis = chID;
        end
        function MOVE_ABSOLUTE(g, chID, loc)
            chStr = sprintf('%02x',chID);
            locInt = round(loc/g.axScale(chID+1));
            ds = g.dlong2hex(locInt);
            g.sendBytes(['53';'04';'06';'00';'91';'01';...
                         '00';chStr;ds(1:2);ds(3:4);ds(5:6);ds(7:8)]);
        end
        function GET_STATUS(g)
            needsCheck = true;
            while (needsCheck)
                for ax = [0:3]
                    g.GET_MOTOR_STATUS(ax);
                    pause(.05);
                end
                if sum(g.axisMoving) > 0
                    needsCheck = true;
                else
                    needsCheck = false;
                end
            end
            disp(sprintf('Current Pos: [%.4f, %.1f, %.1f, %.1f]',g.currentPos(1:4)));
        end            
        
        function parseBytes(g, bytes)
            
            debug = false;
            
            % Read the header packet
            firstByte = bytes(1); 
            secondByte = bytes(2);
            command = bitor(firstByte,bitshift(secondByte,8));
            destByte  = bytes(5);
            source = bytes(6);
            if bitand(destByte,hex2dec('80'))
                dest = destByte - hex2dec('80');
            else
                dest = destByte;
            end
            nDataBytes = bytes(3) + 6;
            
            % If we read in less data than expected from the port...
            if length(bytes) < nDataBytes
                disp('*** Missing data in frame from controller. ***');
                disp('Re-transmitting last command.');
                g.sendBytes(g.lastCommand);
                return;
            end
            
            switch command
                case hex2dec('0006')
                    disp('MGMSG_HW_GET_INFO');
                    disp(sprintf('S/N: %d',g.hex2long(bytes(7:10))));
                    disp(sprintf('Model: %s',bytes(11:18)));
                    disp(sprintf('Type: %d',g.hex2word(bytes(19:20))));
                    disp(sprintf('Firmware Ver: %d.%d.%d',bytes([23,21,22])));
                    disp(sprintf('HW Ver: %d',g.hex2word(bytes(85:86))));
                % nb: These values returned are NOT byteswapped, contrary
                % to docs.
                case hex2dec('0481')
                    g.currentAxis = g.hex2word(bytes(7:8));
                    if debug
                        disp('MGMSG_MOT_GET_STATUSUPDATE');
                        disp(sprintf('Chan ID: %d',g.currentAxis));
                        disp(sprintf('Position: %d',g.hex2longDS(bytes(9:12))));
                    end
                    g.currentPos(g.currentAxis+1) = double(g.hex2longDS(bytes(13:16)))*...
                                                    g.axScale(g.currentAxis+1);
                    if (g.currentAxis > 0) && debug
                        disp(sprintf('Enc (um): %.1f',g.currentPos(g.currentAxis+1)));
                    elseif debug
                        disp(sprintf('Enc (deg): %0.4f',g.currentPos(g.currentAxis+1)));
                    end
                    statusWord = g.hex2longDirect(bytes(17:20));
                    statusBits = {'CW Limit', 'CCW Limit', 'CW Soft Limit',...
                        'CCW Soft Limit','Moving CW','Moving CCW',...
                        'Jogging CW','Jogging CCW','Motor Connected','Homing',...
                        'Homed','unused','Interlock Enabled'};
                    if (bitand(statusWord, bitshift(1,4)) |...
                        bitand(statusWord, bitshift(1,5))) > 0
                        g.axisMoving(g.currentAxis + 1) = 1;
                    else
                        g.axisMoving(g.currentAxis + 1) = 0;
                    end
                    for shift = [0:10,12]
                        if bitand(statusWord,bitshift(1,shift)) > 0
                            if debug
                                disp(statusBits{shift+1});
                            end
                        end
                    end
                % nb: These values ARE returned byteswapped. But it
                % only returns 10 bytes, and doesn't include the channel
                % id.
                case hex2dec('040B')                 
                    rawEnc = double(g.hex2long(bytes(7:10)));
                    scaled = rawEnc*g.axScale(g.currentAxis + 1);
                    g.currentPos(g.currentAxis+1) = scaled; 
                    if debug
                        disp('MGMSG_MOT_GET_ENCCOUNTER');
                        if (g.currentAxis > 0)
                            disp(sprintf('Enc (um): %.1f', scaled));
                        else
                            disp(sprintf('Enc (deg): %.4f', scaled));
                        end
                    end

                otherwise
                    % Print the full command
                    disp(sprintf('%03d ',1:length(bytes)));
                    disp(sprintf('---%c',45*ones(length(bytes),1)));
                    disp(sprintf('%c   ',bytes));
                    disp(sprintf('%02x  ',bytes));
                    disp(sprintf('%03d ',bytes)); 
            end
        end
        
        %% Conversion functions for going to and from hex.
        % The controller seems to play loosely with convention.
        function hex = bytesToHex(g, input)
            if ischar(input)
                hex = input;
            else
                hex = sprintf('%.2x',input);
            end
        end 
        function wordOut = hex2word(g, hexIn)
            hexIn = g.bytesToHex(hexIn);
            wordOut = int16(sscanf(hexIn,'%x'));
        end
        function hexOut = word2hex(g, wordIn)
            hexOut = dec2hex(uint16(wordIn),4);
        end
        function shortOut = hex2short(g, hexIn)
            hexIn = g.bytesToHex(hexIn);
            shortOut = typecast(uint16(sscanf(hexIn,'%x')),'int16');
        end
        function hexOut = short2hex(g, shortIn)
            hexOut = dec2hex(typecast(int16(shortIn), 'uint16'),4);
        end
        function hexOut = dword2hex(g, dwordIn)
            hexOut = dec2hex(swapbytes(uint32(dwordIn)),8);
        end
        function dwordOut = hex2dword(g, hexIn)
            hexIn = g.bytesToHex(hexIn);
            dwordOut = swapbytes(uint32(sscanf(hexIn,'%x')));
        end
        function hexOut = long2hex(g, longIn)
            hexOut = dec2hex(swapbytes(typecast(int32(longIn),'uint32')),8);
        end
        function longOut = hex2long(g, hexIn)
            hexIn = g.bytesToHex(hexIn);
            longOut = swapbytes(typecast(uint32(sscanf(hexIn,'%x')),'int32'));
        end
        function longOut = hex2longDirect(g, hexIn)
            hexIn = g.bytesToHex(hexIn);
            longOut = uint32(sscanf(hexIn,'%x'));
        end
        function longOut = hex2longDS(g, hexIn)
            hexIn = g.bytesToHex(hexIn);
            longOut = typecast(uint32(sscanf(hexIn,'%x')),'int32');
        end
        function hexOut = dlong2hex(g, longIn)
             hexOut = dec2hex(typecast(int32(longIn),'uint32'),8);
        end
        
    end
    
end