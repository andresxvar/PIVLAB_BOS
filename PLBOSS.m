classdef PLBOSS
    %PMBOSS Summary of this class goes here
    %   Detailed explanation goes here

    properties
        Settings
        PreprocessOptions
        PostprocessOptions
        SaveOptions

        BackgroundFilename
        BackgroundImg
        ImageDirectory
        ImageFilenames
        ImageCount

        x
        y
        u
        v
        fileidx
    end

    methods
        function obj = PLBOSS(options)
            %PLBOSS Construct an instance of this class
            %   Detailed explanation goes here
            arguments
                options.BackgroundFilename = []
                options.Directory = []
                options.Filenames = []
                options.Range = []
            end

            % check PIVLAB
            if isempty(which("piv_FFTmulti"))
                error("PLBOSS: requires PIVLAB, add PIVLAB to path or download from: https://www.mathworks.com/matlabcentral/fileexchange/27659-pivlab-particle-image-velocimetry-piv-tool-with-gui/")
            end

            obj = obj.Set_Settings();
            obj = obj.Set_PreprocessOptions();
            obj = obj.Set_PostprocessOptions();
            %obj = obj.Set_SaveOptions();
            obj = obj.Set_BackgroundFilename(options.BackgroundFilename);
            obj = obj.PrepBackground();
            obj = obj.Set_ImageDirectory(options.Directory);
            obj = obj.Set_ImageFilenames(filename=options.Filenames,foi=options.Range);

            obj.ImageCount = numel(obj.ImageFilenames);
        end

        function obj = Set_Settings(obj,options)
            arguments
                obj
                %Parameter                              %Setting           %Options
                options.IntArea1=64;                    % window size of first pass
                options.StepSize1=32;                   % step of first pass
                options.SubPixFinder=1;                 % 1 = 3point Gauss, 2 = 2D Gauss
                options.Mask=[];                        % If needed, generate via: imagesc(image); [temp,Mask{1,1},Mask{1,2}]=roipoly;
                options.ROI=[];                         % Region of interest: [x,y,width,height] in pixels, may be left empty
                options.NumPasses=2;                    % 1-4 nr. of passes
                options.IntArea2=32;                    % second pass window size
                options.IntArea3=16;                    % third pass window size
                options.IntArea4=16;                    % fourth pass window size
                options.WindowDeformation='*linear';    % '*spline' is more accurate, but slower
                options.RepeatedCorrelation=0;          % 0 or 1 : Repeat the correlation four times and multiply the correlation matrices.
                options.DisableAutocorrelation=0;       % 0 or 1 : Disable Autocorrelation in the first pass.
                options.CorrelationStyle=0;             % 0 or 1 : Use circular correlation (0) or linear correlation (1).
                options.DoCorrelationMatrices=0;        % 0 or 1 : Return correlation matrices
                options.RepeatLastPass=0;               % 0 or 1 : Repeat the last pass of a multipass analyis
                options.LastPassQualitySlope=0.025;     % Repetitions of last pass will stop when the average difference to the previous pass is less than this number.
            end
            % make into cell array for PIVLAB code
            obj.Settings = [fieldnames(options) struct2cell(options)];
        end

        function obj = Set_PreprocessOptions(obj,options)
            arguments
                obj
                %Parameter                  %Setting           %Options
                options.ROI=[];             % same as in PIV settings
                options.CLAHE=1;            % 1 = enable CLAHE (contrast enhancement), 0 = disable
                options.CLAHEsize=50;       % CLAHE window size
                options.Highpass=0;         % 1 = enable highpass, 0 = disable
                options.HighpassSize=15;    % highpass size
                options.Clipping=0;         % 1 = enable clipping, 0 = disable
                options.Wiener=0;           % 1 = enable Wiener2 adaptive denoise filter, 0 = disable
                options.WienerSize=3;       % Wiener2 window size
                options.MinIntensity=0.0;   % Minimum intensity of input image (0 = no change)
                options.MaxIntensity=1.0;   % Maximum intensity on input image (1 = no change)
            end
            % make into cell array for PIVLAB code
            obj.PreprocessOptions = [fieldnames(options) struct2cell(options)];
        end

        function obj = Set_PostprocessOptions(obj,options)
            arguments
                obj
                options.CalibrationFactorU=1;       % Calibration factor for u
                options.CalibrationFactorV=1;       % Calibration factor for v
                options.Lims=[-50; 50; -50; 50];    % Maximum allowed velocities, for uncalibrated data: maximum displacement in pixels
                options.StdevCheck=1;               % 1 = enable global standard deviation test
                options.StdevThreshold=7;           % Threshold for the stdev test
                options.LocalMedianCheck=1;         % 1 = enable local median test
                options.LocalMedianThreshold=3;     % Threshold for the local median test
            end
            % make into cell array for PIVLAB code
            obj.PostprocessOptions = [fieldnames(options) struct2cell(options)];
        end

        function obj = Set_BackgroundFilename(obj,filename)
            obj.BackgroundFilename = dirlist(filename);
        end

        function obj = Set_ImageDirectory(obj,directory)
            list = dirlist(directory);
            obj.ImageDirectory = list(1);
        end

        function obj = PrepBackground(obj)
            fprintf('PLBOSS.PREPBACKGROUND: pre-processing background ...')
            img=imread(obj.BackgroundFilename);
            obj.BackgroundImg = PIVlab_preproc (img, obj.PreprocessOptions{:,2});
            fprintf('OK\n');
        end

        function obj = Set_ImageFilenames(obj,options)
            arguments
                obj
                options.filename = "*.tif"
                options.foi = []
            end
            list = dirlist(fullfile(obj.ImageDirectory, options.filename));

            if options.foi
                list = list(options.foi);
            end

            obj.ImageFilenames = list;
        end

        function obj = Analyse(obj,options)
            arguments
                obj
                options.framenum = 1
            end
            image2=imread(obj.ImageFilenames(options.framenum));
            image2 = PIVlab_preproc (image2,obj.PreprocessOptions{:,2});
            [obj.x, obj.y, obj.u, obj.v, ~,~,~] = piv_FFTmulti( ...
                obj.BackgroundImg, ...
                image2, ...
                obj.Settings{:,2}); %actual PIV analysis
            obj.fileidx = options.framenum;
        end

        function Show(obj)
            dsMag = sqrt(obj.u.^2+obj.v.^2);
            imagesc(obj.x(1,:),obj.y(:,1),dsMag);
            axis image;
            title(obj.ImageFilenames(obj.fileidx))
        end
    end
end



function list = dirlist(path)
list = struct2table(dir(path));
list = fullfile(string(list.folder),string(list.name));
if isempty(list)
    error("DIRLIST: no mathes for %s",path)
end
end


