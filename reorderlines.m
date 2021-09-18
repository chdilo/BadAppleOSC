function [BouTemp,p0] = reorderlines(Bou,p0)
% 优化顺序
bouNum = length(Bou);
BouTemp = cell(bouNum, 1);
for j = 1:bouNum
    bouNumLeft = length(Bou);
    mindist = zeros(bouNumLeft, 1);
    mini = zeros(bouNumLeft, 1);
    for i = 1:bouNumLeft
        dist = sum((p0-Bou{i}).^2,2);
        [mindist(i),mini(i)] = min(dist);
    end
    [~, indx] = min(mindist);
    BouTemp{j} = circshift(Bou{indx},-mini(indx)+1);
    p0 = BouTemp{j}(end,:);
    Bou(indx) = [];
end

end