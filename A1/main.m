inputFilename = '/Users/yuchenhuang/Downloads/foreman_cif-1.yuv';
outputFilename = '/Users/yuchenhuang/Downloads/foreman_cif-1_Y.yuv';
v1 = YUVVideo(inputFilename, 352, 288, 420);
y_only = true;
writeToFile(v1, outputFilename, y_only);

inputFilename = '/Users/yuchenhuang/Downloads/foreman_cif-1_Y.yuv';
v1 = YOnlyVideo(inputFilename, 352, 288);
block_width = 64;
block_height = block_width;
[v1WithPadding,v1Averaged] = block_creation(v1, v1.Y,block_width,block_height);

encoded = encoder(v1WithPadding, 2, block_width, block_height,1);

residuaFile = 'Residual.txt';
mvFile = 'MotionVectors.txt';

decoded = decoder(residuaFile, mvFile, 64, 64,384,320,6,10,10);

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

function obj = YUVVideo(filename, width, height, type)
    % Check the input width and height
    if (width <= 0 || height <= 0)
        ME = MException('input video size can not be zero or negative');
        throw(ME);
    else
        obj.width = width;
        obj.height = height;
    end
    % Check the file type
    switch(type)
        case 444
            obj.YUVType = type;
            lengthMultiplier = 3;
            fprintf("444");
        case 422
            obj.YUVType = type;
            lengthMultiplier = 2;
            fprintf("422");
        case 420
            obj.YUVType = type;
            lengthMultiplier = 1.5;
            fprintf("420");
        otherwise
            ME = MException('input video type is not valid');
            throw(ME);
    end
    % Check if the file exists
    if isfile(filename)
        s = dir(filename);
        filesize = s.bytes;
        try
            obj = CalculateFrame(obj, filesize, lengthMultiplier);
            obj = yuvRead(obj, filename, lengthMultiplier);
        catch ME
            throw(ME);
        end
    else
        % File does not exist.
    end
end

function obj = CalculateFrame(obj, filesize, lengthMultiplier)
    nFrames = filesize / (obj.width * obj.height * lengthMultiplier);
    if floor(nFrames) ~= nFrames
        ME = MException('the number of frames is not an integer according to input size');
        throw(ME);
    end
    obj.numberOfFrames = nFrames;
end

function obj = yuvRead(obj, filename, lengthMultiplier)
    switch(obj.YUVType)
        case 444
            widthDivider = 1;
            heightDivider = 1;
        case 422
            widthDivider = 2;
            heightDivider = 1;
        case 420
            widthDivider = 2;
            heightDivider = 2;
    end

    fid = fopen(filename, 'r'); % Open the video file
    stream = fread(fid, '*uchar'); % Read the video file
    length = lengthMultiplier * obj.width * obj.height; % Length of a single frame
    y = uint8(zeros(obj.width, obj.height, obj.numberOfFrames));
    u = uint8(zeros(obj.width / widthDivider, obj.height / heightDivider, obj.numberOfFrames));
    v = uint8(zeros(obj.width / widthDivider, obj.height / heightDivider, obj.numberOfFrames));
    for iFrame = 1:obj.numberOfFrames
        frame = stream((iFrame - 1) * length + 1:iFrame * length);

        % Y component of the frame
        yImage = reshape(frame(1:obj.width * obj.height), obj.width, obj.height);
        % U component of the frame
        uImage = reshape(frame(obj.width * obj.height + 1:1.25 * obj.width * obj.height), obj.width / 2, obj.height / 2);
        % V component of the frame
        vImage = reshape(frame(1.25 * obj.width * obj.height + 1:1.5 * obj.width * obj.height), obj.width / 2, obj.height / 2);
        y(:, :, iFrame) = uint8(yImage);
        u(:, :, iFrame) = uint8(uImage);
        v(:, :, iFrame) = uint8(vImage);
    end
    obj.Y = y;
    obj.U = u;
    obj.V = v;
end

function writeToFile(obj, filename, Y_only)
    fid = fopen(filename, 'w');
    if (fid < 0)
        error('Could not open the file!');
    end
    for i = 1:obj.numberOfFrames
        fwrite(fid, uint8(obj.Y(:, :, i)), 'uchar');
        if (~Y_only)
            fwrite(fid, uint8(obj.U(:, :, i)), 'uchar');
            fwrite(fid, uint8(obj.V(:, :, i)), 'uchar');
        end
    end
    fclose(fid);
end

