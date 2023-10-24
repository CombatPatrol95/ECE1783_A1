%entropy
function obj = encodeExpGolomblist(obj)
           obj.bitstream = '';
           for i=1:1:size(obj.encodereorderedList,2)
               bits =  obj.encodeExpGolombValue((obj.encodereorderedList(i)));
               obj.bitstream = [obj.bitstream, bits];
           end
end

function r = encodeExpGolombValue(~,value)
            if value > 0
                value = 2*value - 1;
            else
                value = -2 * value;
            end
            r = '';
            M = floor(log2(value + 1));
            info = dec2bin(value + 1 - 2^M,M);
            for j=1:M
                r = [r '0'];
            end
            r = [r '1'];
            r = [r info];
end

%quant
function qtc = quantizeBlock(obj, block)
    for x=1:1:obj.block_height
        for y=1:1:obj.block_width
            qtc(x,y) = round(block.data(x,y)/obj.qMatrix(x,y));
        end
    end
end

function obj = quantizeFrame(obj)
    for i=1:obj.block_height:size(obj.transformCoefficientFrame,1)  
        for j=1:obj.block_width:size(obj.transformCoefficientFrame,2)
                currentBlock = Block(obj.transformCoefficientFrame, j,i, obj.block_width, obj.block_height, MotionVector(0,0) );
                qtc =  obj.quantizeBlock(currentBlock);
                obj.quantizationResult(i:i+obj.block_height - 1, j:j+obj.block_width -1 ) = qtc;
        end
    end
    obj.quantizationResult = uint8(obj.quantizationResult);
end

%rescaling
function maxValue = calculateQPMax(obj)
    %calculate maximum possible value for quantizationParameter
    maxValue = log2(obj.block_width)+7;
end

function obj = generateQMatrix(obj)
    for x=1:1:obj.block_height
        for y=1:1:obj.block_width
            if (x + y - 2 < obj.block_height - 1)
                obj.qMatrix(x,y) = power(2, obj.quantizationParameter);
            elseif(x + y - 2 == obj.block_height - 1)
                obj.qMatrix(x,y) = power(2, obj.quantizationParameter + 1);
            else
                obj.qMatrix(x,y) = power(2, obj.quantizationParameter + 2);
            end
        end
    end
end

function qt = rescalingBlock(obj, qtcblock)
    qt = zeros(obj.block_height, obj.block_width);
    for x=1:1:obj.block_height
        for y=1:1:obj.block_width
            qt(x,y) = round(qtcblock.data(x,y) * obj.qMatrix(x,y));
        end
    end
end

function obj = rescalingFrame(obj)
    for i=1:obj.block_height:size(obj.qtcFrame,1)  
        for j=1:obj.block_width:size(obj.qtcFrame,2)
                currentBlock = Block(obj.qtcFrame, j,i, obj.block_width, obj.block_height, MotionVector(0,0) );
                qt =  obj.rescalingBlock(currentBlock);
                obj.rescalingResult(i:i+obj.block_height - 1, j:j+obj.block_width -1 ) = qt;
        end
    end
end

%diff encoding
function diff_motionvector = differential_vector(obj)
    first_mv=0;
    for j=1:1:obj.mvwidth
        for i=1:1:obj.mvlength
            if(i==1)
                diff_motionvector(i,j)=first_mv-obj.motionvector(i,j);
                continue;
            end
            diff_motionvector(i,j)=obj.motionvector(i-1,j)-obj.motionvector(i,j);
        end
    end
    
end

function diff_modes = differential_modes(obj)
    first_mode=0;
    
    for j=1:1:obj.modewidth
        for i=1:1:obj.modelength
            if(i==1)
                if(first_mode==obj.modes(i,j))
                    diff_modes(i,j)=0;
                else
                    diff_modes(i,j)=-1;
                end
                continue
            end
            
            if(obj.modes(i,j)==obj.modes(i-1,j))
                diff_modes(i,j)=0;
            else
                diff_modes(i,j)=-1;
            end
        end
    end
    
end

%reverse entropy
function [symbol,i] = dec_golomb(i,bits)
    % i = 1;
    length_M = 0;
    x = 0; % x is a flag to exit when decoding of symbol is done
    while x<1
        switch bits(i)
            case '1'
                if (length_M == 0)
                    symbol = 0;
                    i = i + 1;
                    x = 1;
                else
                    info = bin2dec(bits(i+1 : i+length_M));
                    symbol = 2^length_M + info -1;
                    i = i + length_M + 1;
                    length_M = 0;
                    x = 1;
                end
    
            case '0'
                length_M = length_M + 1;
                i = i + 1;
        end
    end
    symbol = (-1)^(symbol+1)*ceil(symbol/2);
end