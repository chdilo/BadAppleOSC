clear,clc,close all
% 输入一个视频,输出其二值化后边缘点的坐标组成的波形文件
% 左声道:水平坐标
% 右声道:垂直坐标
scanNumPF = 2; % 每帧扫描次数
Fs = 48e3; % 采样率
[vidFile, vidPath] = uigetfile('*.avi;*.mp4', '选择视频文件', '22118703_5_0.mp4');
[wavFile, wavPath] = uiputfile({'*.wav';'*.flac'}, '保存音频文件', 'PlayMe');

%% 读取视频文件
disp('正在加载文件...');
Vid = VideoReader([vidPath vidFile]);
vidFrameRate = Vid.FrameRate; % 帧率
nFrames = Vid.NumFrames; % 总帧数
vidHeight = Vid.Height; % 高度
vidWidth = Vid.Width; % 宽度
Vid.CurrentTime = 0; % 指定应在距视频开头多少秒的位置开始读取
WHR = vidWidth/vidHeight;

dotNumPF = Fs/vidFrameRate; % 每帧点数
dotNum = dotNumPF/scanNumPF; % 每次扫描点数

%% 读取帧并处理
disp('正在处理帧...');
Fig = waitbar(0,'正在处理帧...');
bouDotxy = cell(dotNumPF*nFrames, 1);
p0 = [(1024/WHR+1)/2, (1024+1)/2];
k = 1;
while hasFrame(Vid)
    vidFrame = readFrame(Vid); % 读取每帧图像
    vidFrame = im2double(vidFrame);
    vidFrame = rgb2gray(vidFrame);
    vidFrame = imresize(vidFrame,[NaN 1024]);
    vidFrame = imgaussfilt(vidFrame, 1024/dotNum) >= 0.5; % 滤波
    vidFrame = edge(double(vidFrame), 'Canny'); % 边缘检测
    Bou = bwboundaries(vidFrame); % 获取边界坐标

    % 优化顺序
    [BouTemp,p0] = reorderlines(Bou,p0);
    if isempty(Bou)
        p0 = [(1024/WHR+1)/2, (1024+1)/2];
    end
    
    bouDot = cell2mat(BouTemp); % 边界上的每一点
    bouDotNum = length(bouDot); % 每一帧点的数量
    if bouDotNum > 0
        bouDot = resample(bouDot, dotNum, bouDotNum, 0); % 调整点数
        bouDotTemp = repmat(bouDot, scanNumPF, 1); % 每帧重复扫描scanNumPF次
    else
        bouDotTemp = NaN(dotNumPF, 2); % 无画面
    end

    bouDotxy{k} = bouDotTemp; % 所有要描的点的坐标
    waitbar(k/nFrames, Fig,...
        sprintf('正在处理帧...%.2f%%(%u/%u)',k/nFrames*100,k,nFrames));
    k = k + 1;
end
close(Fig)

%% 调整幅度
disp('调整幅度...')
bouDotxy = cell2mat(bouDotxy);
bouDotxy = bouDotxy - mean(bouDotxy, 'omitnan'); % 移除直流
bouDotxy = bouDotxy / max(abs(bouDotxy),[],'all'); % 归一化
% 顺时针旋转90°
bouDotxy(:,1) = -bouDotxy(:,1); % 水平翻转
bouDotxy(:,[1 2]) = bouDotxy(:,[2 1]); % 交换xy
% 无画面的点
bouDotxy(isnan(bouDotxy)) = 0;

%% 绘制PSD
% 查看频谱范围,大部分能量应在听域内(20Hz~20kHz)
winlen = 2*Fs; % 窗长度
window = hanning(winlen, 'periodic'); % 窗口函数
noverlap = winlen/2; % 数据重叠
nfft = winlen; % FFT点数
[pxx, f] = pwelch(bouDotxy, window, noverlap, nfft, Fs, 'onesided');
semilogx(f, pxx)
xlabel('频率(Hz)')
ylabel('功率')

%% 输出音频文件
disp('输出...')
audiowrite([wavPath wavFile], bouDotxy, Fs)

