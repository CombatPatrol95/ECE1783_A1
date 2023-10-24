function obj = decoder(inputFilename1, inputFilename2, block_width, block_height,decoderwidth,decoderheight,mvwidth,mvheight,numberOfFrames)

    inputFilename = '/Users/yuchenhuang/Downloads/foreman_cif-1_Y.yuv';
    v1 = YOnlyVideo(inputFilename, 352, 288);
    [v1WithPadding,v1Averaged] = block_creation(v1, v1.Y,block_width,block_height);

    fid = fopen(inputFilename1, 'r');
    a=fread(fid,'int16');
    fclose(fid); 
    fid = fopen(inputFilename2, 'r');
    b=fread(fid,'int16');
    fclose(fid); 
    
    obj.dw=decoderwidth;
    obj.dh=decoderheight;
    obj.mvw=mvwidth;
    obj.mvh=mvheight;
   
    obj.inputFilename=inputFilename1;
    obj.numberOfFrames=numberOfFrames;
    
    residualVideo=permute(reshape(a,decoderwidth,decoderheight,numberOfFrames),[1,2,3]);
    mv=permute(reshape(b,mvwidth,mvheight,numberOfFrames),[1,2,3]);
    
    obj.vectors = mv;
    obj.video = residualVideo;
    obj.block_width = block_width;
    obj.block_height = block_height;
    obj.referenceFrame(1:decoderwidth,1:decoderheight,1) = uint8(128);
    %obj.referenceFrame(1:decoderwidth,1:decoderheight,2:10) = obj.video(:,:,2:10);
    obj.Temp_v = YOnlyVideo('Reconstructed.yuv', obj.dw,  obj.dh);

    psnr_data = zeros(1, numberOfFrames);
    mae_data = zeros(1, numberOfFrames);

    for p = 1:1: numberOfFrames
        obj.originalFrame = v1WithPadding.Y(:,:,p);
        obj.residualFrame=residualVideo(:,:,p);
        obj.v = obj.vectors(:,:,p);
        col=1;
        row=1;
        for i=1:obj.block_height:size(obj.residualFrame,1)
         
            for j=1:obj.block_width:size(obj.residualFrame,2)
                obj.x = obj.v(row,col);
                obj.y = obj.v(row,col+1);

                obj.predictedFrame(i:i+obj.block_height - 1, j:j+obj.block_width -1) = obj.referenceFrame(i+(obj.x):i+(obj.x)+obj.block_height - 1, j+(obj.y):j+(obj.y)+obj.block_width -1 );
  
                col = col + 2;
            end
            row = row + 1;
            col = 1;     
        end
        referenceFrame_cal=int16(obj.predictedFrame)+int16(obj.residualFrame);
        obj.referenceFrame=uint8(referenceFrame_cal);

        residual_after_compensation = obj.originalFrame - obj.Temp_v.Y(:,:,p);
        
        %obj.Temp_v.Y(:,:,p)=referenceFrame;
        %obj.referenceVideo(:,:,p) = uint8(referenceFrame_cal);

        psnr_value = psnr(obj.originalFrame, obj.Temp_v.Y(:,:,p));
        %mae_value = mae(original_frame, obj.Temp_v.Y);

        psnr_data(p) = psnr_value;
        %mae_data(p) = mae_value;
        figure('Position', [100, 100, 1200, 400]);
       
        subplot(1,5,1), imshow(uint8(obj.predictedFrame(:,:,1)))
        subplot(1,5,2), imshow(uint8(obj.residualFrame(:,:,1)))
        subplot(1,5,3), imshow(residual_after_compensation(:,:,1)) 

         saveas(gcf, fullfile(sprintf('subplots_frame_%d.png', p)));
                
    end
    figure;
    subplot(2, 1, 1);
    plot(psnr_data);
    title('PSNR per frame');

    subplot(2, 1, 2);
    plot(mae_data);
    title('MAE per frame');
end

function getMAE_metric(obj)
    averageMAE = zeros(1, 10);

    for p = 1:1:10
        current = double(obj.video.Y(:,:,p));
        reconstructed =double(obj.reconstructedVideo(:,:,p));

        % Calculate the absolute difference between frames
        abs_diff = abs(current - reconstructed);

        % Calculate the MAE for the frame
        frameMAE = mean(abs_diff, 'all');
        averageMAE(p) = frameMAE;

    end

    frame_number = 1:10;
    plot(frame_number, averageMAE)
    title('MAE Metric');
    xlabel('Frames')
    ylabel('MAE values')
end

function obj = YOnlyVideo(filename, width, height)
    % Check the input width and height
    if (width <= 0 || height <= 0)
        ME = MException('input video size can not be zero or negative');
        throw(ME);
    else
        obj.width = width;
        obj.height = height;
    end

    % Check file is exist
    if isfile(filename)
        s = dir(filename);
        filesize = s.bytes;
        try
            obj = CalculateFrameLen(obj, filesize);
            obj = yOnlyRead(obj, filename);
        catch ME
            throw(ME);
        end
    else
        % File does not exist.
    end
end

function copyobj = clone(obj)
    copyobj = obj;
end

function obj = CalculateFrameLen(obj, filesize)
    nFrames = filesize / (obj.width * obj.height);
    if floor(nFrames) ~= nFrames
        ME = MException('the number of frames is not an integer according to input size');
        throw(ME);
    end
    obj.numberOfFrames = nFrames;
end

function obj = yOnlyRead(obj, filename)
    fid = fopen(filename, 'r'); % Open the video file
    stream = fread(fid, '*uchar'); % Read the video file
    length = obj.width * obj.height; % Length of a single frame
    y = uint8(zeros(obj.width, obj.height, obj.numberOfFrames));

    for iFrame = 1:obj.numberOfFrames
        frame = stream((iFrame - 1) * length + 1:iFrame * length);
        % Y component of the frame
        yImage = reshape(frame(1:obj.width * obj.height), obj.width, obj.height);
        y(:, :, iFrame) = uint8(yImage);
    end
    obj.Y = y;
end

function [paddedVideo, paddedAverageVideo] = block_creation(obj, Y, block_width, block_height)
    pad_len = 0;
    pad_height = 0;
    paddedVideo = clone(obj);
    if (rem(obj.width, block_width) == 0)
        Y_block(1:block_width, 1:block_height) = 0;
    else
        pad_len = block_width - (rem(obj.width, block_width));
        paddedVideo.width = obj.width + pad_len;
    end

    if (rem(obj.height, block_height) == 0)
        Y_block(1:block_width, 1:block_height) = 0;
    else
        pad_height = block_height - (rem(obj.height, block_height));
        paddedVideo.height = obj.height + pad_height;
    end
    paddedAverageVideo = clone(paddedVideo);
    Y_New = Y;
    Y_New(obj.width + 1:obj.width + pad_len, obj.height + 1:obj.height + pad_height, :) = uint8(127);
    Y_New(:, obj.height + 1:obj.height + pad_height, :) = uint8(127);
    Y_New(obj.width + 1:obj.width + pad_len, :, :) = uint8(127);

    for k = 1:1:obj.numberOfFrames
        for i = 1:block_width:obj.width + pad_len
            for j = 1:block_height:obj.height + pad_height
                Y_block = Y_New(i:i + block_width - 1, j:j + block_height - 1, k);
                mean_value = round(mean(Y_block, 'all'));
                av_Y(i:i + block_width - 1, j:j + block_height - 1, k) = uint8(mean_value);
            end
        end
    end

    paddedVideo.Y = Y_New;
    paddedAverageVideo.Y = av_Y;
end
