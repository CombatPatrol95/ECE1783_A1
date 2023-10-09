% Read Y-component of 4:2:0 video sequences and dump it into Y-only files
yuvFile = 'D:\CourseMaterial\ECE1783_TRADOFF_DIGIT\A1\foreman_cif-1.yuv';
width = 352;
height = 288;
frameSize = width * height * 1.5;

fid = fopen(yuvFile, 'rb');
yuvData = fread(fid, inf, 'uint8');
fclose(fid);

% Extract Y plane
yPlane = yuvData(1:frameSize);

% Write Y component to Y-only file
fid = fopen('Y_only.yuv', 'wb');
fwrite(fid, yPlane, 'uint8');
fclose(fid);

% Parameters
blockSizes = [2, 8, 64]; % i values
searchRanges = [1, 4, 8]; % r values
nValues = [1, 2, 3]; % n values

% Loop through different block sizes
for iIdx = 1:length(blockSizes)
    i = blockSizes(iIdx);
    
    % Split each frame into (i x i) blocks and pad
    numBlocksX = width / i;
    numBlocksY = height / i;

    % Read reference frame (previous frame)
    prevFrameStart = 1; % Adjust this based on the structure of your YUV file
    prevFrameEnd = prevFrameStart + frameSize - 1;
    referenceFrame = yuvData(prevFrameStart:prevFrameEnd);

    % Perform motion estimation for each block
    for blockX = 1:numBlocksX
        for blockY = 1:numBlocksY
            % Extract current block (i x i) from Y plane
            currentBlock = yPlane((blockY-1)*i*width + (blockX-1)*i + 1 : blockY*i*width + blockX*i);
            
            % Perform motion estimation using integer pixel full search
            bestMAE = Inf;
            bestMV = [0, 0];
        % Iterate through candidate motion vectors in the search range
            for mvY = -r:r
                for mvX = -r:r
                    % Compute the candidate block in the reference frame
                    refBlockY = blockY - 1 + mvY;
                    refBlockX = blockX - 1 + mvX;
                    
                    % Check if the candidate block is within the frame boundary
                    if refBlockY >= 1 && refBlockY <= numBlocksY && refBlockX >= 1 && refBlockX <= numBlocksX
                        % Extract candidate block from the reference frame
                        refBlock = referenceFrame((refBlockY-1)*i*width + (refBlockX-1)*i + 1 : refBlockY*i*width + refBlockX*i);
                        
                        % Compute Mean Absolute Error (MAE) between currentBlock and refBlock
                        mae = sum(abs(currentBlock - refBlock)) / numel(currentBlock);
                        
                        % Update bestMV and bestMAE if the current candidate has smaller MAE
                        if mae < bestMAE
                            bestMAE = mae;
                            bestMV = [mvX, mvY];
                        elseif mae == bestMAE
                            % If there is a tie, choose the block with the smallest motion vector
                            % (L1 norm: |x| + |y|)
                            currentL1Norm = abs(mvX) + abs(mvY);
                            bestL1Norm = abs(bestMV(1)) + abs(bestMV(2));
                            if currentL1Norm < bestL1Norm
                                bestMV = [mvX, mvY];
                            elseif currentL1Norm == bestL1Norm
                                % If there is still a tie, choose the block with smallest y, then x
                                if mvY < bestMV(2) || (mvY == bestMV(2) && mvX < bestMV(1))
                                    bestMV = [mvX, mvY];
                                end
                            end
                        end
                    end
                end
            end            
                    % Use bestMV to retrieve predicted block from the reference frame
            refBlockY = blockY - 1 + bestMV(2);
            refBlockX = blockX - 1 + bestMV(1);
            predictedBlock = referenceFrame((refBlockY-1)*i*width + (refBlockX-1)*i + 1 : refBlockY*i*width + refBlockX*i);
        
            % Generate residual block
            residualBlock = currentBlock - predictedBlock;
            
            % Approximate residual block by rounding to nearest multiple of 2^n
            for nIdx = 1:length(nValues)
                n = nValues(nIdx);
                approximatedResidualBlock = round(residualBlock / (2^n)) * (2^n);
                
                % Store approximated residual block to a text file
                % dlmwrite('residual_blocks.txt', approximatedResidualBlock, '-append');
                
                % Add approximated residual block to predicted block
                reconstructedBlock = predictedBlock + approximatedResidualBlock;
                
                % Store reconstructed block in video frame
                % Update predictedBlock for next iteration
            end
        end
    end
    
    % Write reconstructed Y component to Y-only-reconstructed file
    fid = fopen(['Y_reconstructed_i', num2str(i), '.yuv'], 'wb');
    fwrite(fid, yPlaneReconstructed, 'uint8');
    fclose(fid);
    
    % Compare original Y-only file with reconstructed Y-only file
    % Compute subjective and objective quality metrics
    % Highlight cases based on content type, resolution, i, r, and n values
end
