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
    numBlocksX = floor(width / i);
    numBlocksY = floor(height / i);

    % Initialize the reconstructed Y component
    yPlaneReconstructed = zeros(1, frameSize);

    % Initialize an array to store motion vectors
    motionVectors = zeros(numBlocksX * numBlocksY, 2);

    % Read reference frame (previous frame)
    prevFrameStart = 1; % Adjust this
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
            for rIdx = length(searchRanges)
                r = searchRanges(rIdx)
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
            end

            % Store bestMV to the motionVectors array
            motionVectors((blockY-1)*numBlocksX + blockX, :) = bestMV;

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
                
                % Store approximated residual block in the array
                approximatedResiduals{blockY, blockX, nIdx} = approximatedResidualBlock;
                
                % Add approximated residual block to predicted block
                reconstructedBlock = predictedBlock + approximatedResidualBlock;
                
                % Store reconstructed block in video frame
                yPlaneReconstructed((blockY-1)*i*width + (blockX-1)*i + 1 : blockY*i*width + blockX*i) = reconstructedBlock;
                
                % Update predictedBlock for next iteration
                predictedBlock = reconstructedBlock;
            end
        end
    end
    
    % Write motion vectors to a file
    mvFileName = ['motion_vectors_i', num2str(i), '.txt'];
    writematrix(motionVectors, mvFileName);

    % Write approximated residuals to a file
    for nIdx = 1:length(nValues)
        n = nValues(nIdx);
        approximatedResidualFileName = ['approximated_residuals_i', num2str(i), '_n', num2str(n), '.txt']; % txt format for residuals
        approximatedResidualsArray = cat(1, approximatedResiduals{:, :, nIdx});
        writematrix(approximatedResidualsArray, approximatedResidualFileName);
    end

    % Write reconstructed Y component to Y-only-reconstructed file
    fid = fopen(['Y_reconstructed_i', num2str(i), '.yuv'], 'wb');
    fwrite(fid, yPlaneReconstructed, 'uint8');
    fclose(fid);
    
    % Compare original Y-only file with reconstructed Y-only file
    % Compute subjective and objective quality metrics
    % Highlight cases based on content type, resolution, i, r, and n values
end

%% 

%---------------------decoder below----------------
for iIdx = 1:length(blockSizes)
    i = blockSizes(iIdx);
    
    for nIdx = 1:length(nValues)
        n = nValues(nIdx);
        
        % Load motion vectors and approximated residual blocks generated during encoding
        mvFileName = ['motion_vectors_i', num2str(i), '.txt'];
        motionVectors = readmatrix(mvFileName);

        % Load approximated residual blocks generated during encoding
        approximatedResidualFileName = ['approximated_residuals_i', num2str(i), '_n', num2str(n), '.txt'];
        approximatedResidualData = readmatrix(approximatedResidualFileName);
        
        % Initialize the decoded Y component
        yPlaneDecoded = zeros(1, frameSize);
        
        % Initialize predictor block for the first frame
        if iIdx == 1 && nIdx == 1
            predictorBlock = ones(1, i * i) * 128;
        end
        
        % Loop through blocks and decode Y component
        for blockIdx = 1:size(motionVectors, 1)
            % Extract motion vector and approximated residual block
            mvX = motionVectors(blockIdx, 1);
            mvY = motionVectors(blockIdx, 2);
            approximatedResidualBlock = reshape(approximatedResidualData((blockIdx - 1) * i * i + 1 : blockIdx * i * i), 1, []);
            
            % Calculate position in the Y plane
            blockX = mod(blockIdx - 1, width / i) + 1;
            blockY = floor((blockIdx - 1) / (width / i)) + 1;
            yStart = (blockY - 1) * i * width + (blockX - 1) * i + 1;
            
            % Apply motion vector to get predictor block
            predictorX = max(1, min(width - i + 1, blockX * i + mvX));
            predictorY = max(1, min(height - i + 1, blockY * i + mvY));
            predictorStart = (predictorY - 1) * width + predictorX;
            predictorBlock = yPlaneDecoded(predictorStart : predictorStart + i * i - 1);
            
            % Add approximated residual block to the predictor block
            decodedBlock = predictorBlock + approximatedResidualBlock;
            
            % Store decoded block in the Y component
            yPlaneDecoded(yStart : yStart + i * i - 1) = decodedBlock;
        end
        
        % Write decoded Y component to Y-only-decoded file
        decodedFile = ['Y_decoded_i', num2str(i), '_n', num2str(n), '.yuv'];
        fid = fopen(decodedFile, 'wb');
        fwrite(fid, yPlaneDecoded, 'uint8');
        fclose(fid);
        
        % Compare decoded Y-only file against the Y-only-reconstructed file
        % Perform comparison, compute metrics, and ensure they match
        % Compute PSNR and SSIM
        % decodedFile = ['Y_decoded_i', num2str(i), '_n', num2str(n), '.yuv'];
        decodedYUV = fread(fopen(decodedFile, 'rb'), inf, 'uint8');
        
        % Assuming that the reconstructed Y component is already loaded from the variable yPlaneReconstructed
        
        % Calculate PSNR and SSIM
        decodedYUV = decodedYUV(1:frameSize); % Ensure the size matches
        decodedYUV = reshape(decodedYUV, width, [])';
        psnrValue = psnr(yPlaneReconstructed, decodedYUV);
        ssimValue = ssim(yPlaneReconstructed, decodedYUV);
        
        % Display PSNR and SSIM
        disp(['For i = ', num2str(i), ', n = ', num2str(n)]);
        disp(['PSNR: ', num2str(psnrValue), ' dB']);
        disp(['SSIM: ', num2str(ssimValue)]);
        
        % Ensure decoded Y-only file matches the reconstructed Y-only file
        if psnrValue < threshold || ssimValue < threshold
            disp('Warning: Quality mismatch detected!');
            % Implement your logic to handle the mismatch, e.g., alert, logging, etc.
        else
            disp('Y-only file matches the reconstructed Y-only file.');
        end
    end
end
