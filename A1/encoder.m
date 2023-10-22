function obj = encoder(video, r, block_width, block_height, n)
    obj = struct();
    obj.video = video;
    obj.r = r;
    obj.n = n;
    obj.block_width = block_width;
    obj.block_height = block_height;
    ReferenceFrame(1:video.width, 1:video.height) = uint8(127);

    for i = 1:10
        m = createMotionEstimationFrames(r, video.Y(:, :, i), ReferenceFrame, block_width, block_height, n);
        m = truncateBlock(m);
        ReferenceFrame = m.reconstructed;
        obj.residualVideo(:, :, i) = m.residualFrame;
        obj.reconstructedVideo(:, :, i) = m.reconstructed;
        obj.motionVectorVideo(:, :, i) = m.blocks;

        fprintf("the %d th frame has been processed\n", i);
    end
    fid = fopen('Residual.txt', 'w');
    fwrite(fid,int16(obj.residualVideo()),'int16'); 
    fclose(fid); 
    fid = fopen('MotionVectors.txt', 'w');
    fwrite(fid,int16(obj.motionVectorVideo()),'int16'); 
    fclose(fid); 
end

function obj = createMotionEstimationFrames(r, currentFrame, referenceFrame, block_width, block_height, n)
    obj = struct();
    obj.r = r;
    obj.block_width = block_width;
    obj.block_height = block_height;
    obj.currentFrame = currentFrame;
    obj.referenceFrame = referenceFrame;
    obj.n = n;
    obj = truncateBlock(obj);
end

function obj = truncateBlock(obj)
    col = 1;
    row = 1;
    for i = 1:obj.block_height:size(obj.currentFrame, 1)
        for j = 1:obj.block_width:size(obj.currentFrame, 2)
            currentBlock = Block(obj.currentFrame, j, i, obj.block_width, obj.block_height, MotionVector(0, 0));
            referenceBlockList = getAllBlocks(obj, i, j);
            bestMatchBlock = findBestPredictedBlockSAD(obj, referenceBlockList, currentBlock.getBlockSumValue());
            residualBlock = int16(currentBlock.data) - int16(bestMatchBlock.data);
            r = roundBlock(obj, int16(residualBlock), obj.n);

            obj.predictedFrame(i:i + obj.block_height - 1, j:j + obj.block_width - 1) = obj.referenceFrame(bestMatchBlock.top_height_index:bestMatchBlock.top_height_index + obj.block_height - 1, bestMatchBlock.left_width_index:bestMatchBlock.left_width_index + obj.block_width - 1);
            obj.residualFrame(i:i + obj.block_height - 1, j:j + obj.block_width - 1) = r;

            obj.blocks(row, col) = bestMatchBlock.MotionVector.x;
            obj.blocks(row, col + 1) = bestMatchBlock.MotionVector.y;
            col = col + 2;
        end
        row = row + 1;
        col = 1;
    end
    reconstructed_cal = int16(obj.predictedFrame(:, :, 1)) + int16(obj.residualFrame(:, :, 1));
    obj.reconstructed = uint8(reconstructed_cal);
    obj.predictedFrame = uint8(obj.predictedFrame);
    obj.residualFrame = int16(obj.residualFrame);
end

function result = roundBlock(obj, r, n)
    multiple = 2^n;
    result = r;
    for i = 1:1:size(r, 2)
        for j = 1:1:size(r, 1)
            if mod(r(i, j), multiple) ~= 0
                if mod(r(i, j), multiple) >= multiple / 2
                    % rounding up
                    result(i, j) = (multiple - mod(r(i, j), multiple)) + r(i, j);
                else
                    % round down
                    result(i, j) = r(i, j) - mod(r(i, j), multiple);
                end
            end
        end
    end
end

function blockList = getAllBlocks(obj, row, col)
    if row - obj.r < 1
        i_start = 1;
        i_end = row + obj.r;
    else
        i_start = row - obj.r;
        if row + obj.block_height + obj.r > size(obj.referenceFrame, 1)
            i_end = row;
        else
            i_end = row + obj.r;
        end
    end

    if col - obj.r < 1
        j_start = 1;
        j_end = col + obj.r;
    else
        j_start = col - obj.r;
        if col + obj.block_width + obj.r > size(obj.referenceFrame, 2)
            j_end = col;
        else
            j_end = col + obj.r;
        end
    end

    blockList = [];
    for i = i_start:1:i_end
        for j = j_start:1:j_end
            blockList = [blockList; Block(obj.referenceFrame, j, i, obj.block_width, obj.block_height, MotionVector(i - row, j - col))];
        end
    end
end

function r = findBestPredictedBlockSAD(obj, referenceBlockList, currentBlockSum)
    minimumValue = 9999999;
    for i = 1:1:length(referenceBlockList)
        diff = abs(currentBlockSum - referenceBlockList(i).getBlockSumValue());
        if diff < minimumValue
            minimumValue = diff;
            r = referenceBlockList(i);
        elseif diff == minimumValue
            if referenceBlockList(i).MotionVector.getL1Norm() < r.MotionVector.getL1Norm()
                r = referenceBlockList(i);
            elseif referenceBlockList(i).MotionVector.getL1Norm() == r.MotionVector.getL1Norm()
                if referenceBlockList(i).left_width_index < r.left_width_index
                    r = referenceBlockList(i);
                end
            end
        end
    end
end