clearvars;

filename_no_ext = 'diff_ch_moving';
figs_ext = 'png';

% RSSI graphs
y_axis_rssi_lower = -90;
y_axis_rssi_upper = -20;
% PDR graphs
y_axis_pdr_lower = 95;
y_axis_pdr_upper = 100;
% IAT graphs
y_axis_iat_lower = 0;
y_axis_iat_interval = 250;
y_axis_iat_upper = 1000;
% Packet Loss graphs
y_axis_packet_loss_lower = 0;
y_axis_packet_loss_interval = 250;
y_axis_packet_loss_upper = 1000;
% Generic
x_axis_lower = 0;
x_axis_upper = 120;

load(strcat(filename_no_ext, '.mat'));

ExpMacSource = '2c:56:dc:26:17:77';
ExpProtocol = 'UDP';
% BSSID in regular AP
ExpBSSIDAP1 = '00:c0:ca:90:79:29';
% BSSID in WDS slave AP
%ExpBSSIDAP1 = '00:c0:ca:90:79:28';

ExpBSSIDAP2 = '00:c0:ca:90:79:3e';

% Get WiFi UDP packets
pRSSI = RSSI(strcmp(Protocol, ExpProtocol) & ~isnan(Data) & strcmp(MacSource, ExpMacSource));
pNo = No(strcmp(Protocol, ExpProtocol) & ~isnan(Data) & strcmp(MacSource, ExpMacSource));
pTime = Time(strcmp(Protocol, ExpProtocol) & ~isnan(Data) & strcmp(MacSource, ExpMacSource));
pData = Data(strcmp(Protocol, ExpProtocol) & ~isnan(Data) & strcmp(MacSource, ExpMacSource));
pBSSID = BSSID(strcmp(Protocol, ExpProtocol) & ~isnan(Data) & strcmp(MacSource, ExpMacSource));

pAp(strcmp(pBSSID, ExpBSSIDAP1)) = 1;
pAp(strcmp(pBSSID, ExpBSSIDAP2)) = 2;
pAp = pAp';
pData = pData + 1 - min(pData);
packets = [pNo pTime pAp pRSSI pData];

% HINT: UDP packets may be received out of order, so they need to be sorted

for i = 1:length(packets)
    packetsRx(packets(i, 5), :) = packets(i, :);
end

% Sort packets by data (UDP ID) and then packet ID to break ties (although
% there shouldn't be duplicated packets at this point)
packetsRxSort = sortrows(packetsRx, [5, 1]);
% Remove blank rows
packetsRxSort(packetsRxSort(:, 5)<1, :) = [];
% For each packet, get how many packets between the previous one and this
% one were lost (works out because packets are sorted by UDP ID)
% Example: packetsRxSort(:, 5) = [1 1 2 3 5 8 13 21];
%          y = diff(packetsRxSort(:, 5));
%          y = [0 1 1 2 3 5 8]
difData = [0; diff(packetsRxSort(:, 5)) - 1];
% Since packets can be send more than once, the STA may receive duplicate
% packets. Here, diff could result in -1, which doesn't make sense.
% Therefore, negative numbers should be zeroed.
difData(difData<0) = 0;
% Packet Delivery Ratio (PDR): number of packets received vs number of packets
% sent out by the sender, in percentage
pdr = 100*(1-tsmovavg(difData, 's', 100, 1)/100);
% Inter Arrival Time (IAT): Time between each packet arrival and the next
% one
iat = [0; 1000*abs(diff(packetsRxSort(:, 2)))];
% Packets with different AP transmitter than the previous one
packetsLostSum = cumsum(difData);
% Get percentage of packets lost vs packets sent (assuming last packet
% received is last packet sent)
packetsLostPctg = 100*packetsLostSum(size(packetsLostSum, 1), 1)/packetsRxSort(size(packetsRxSort, 1), 5);
packetsTxSortIds = 1:packetsRxSort(size(packetsRxSort, 1), 5);
packetsTxSortIds = packetsTxSortIds';
% 1st column: packet UDP id
packetsLost(:, 1) = setdiff(packetsTxSortIds, packetsRxSort(:, 5));
% 2nd column: estimated times
for i=1:size(packetsLost, 1)
    i_lower  = find(packetsRxSort(:, 5) <= packetsLost(i, 1), 1, 'last');
    i_upper  = find(packetsRxSort(:, 5) >= packetsLost(i, 1), 1, 'first');
    time_lower = packetsRxSort(i_lower, 2);
    time_upper = packetsRxSort(i_upper, 2);
    % Estimated time will be mean of upper and lower packets time
    % difference
    packetsLost(i, 2) = time_lower + (time_upper - time_lower) / 2;
end

% Get beacons
bBSSID = BSSID(strcmp(MacTransmitter, ExpBSSIDAP1) | strcmp(MacTransmitter, ExpBSSIDAP2));
bRSSI = RSSI(strcmp(MacTransmitter, ExpBSSIDAP1) | strcmp(MacTransmitter, ExpBSSIDAP2));
bNo = No(strcmp(MacTransmitter, ExpBSSIDAP1) | strcmp(MacTransmitter, ExpBSSIDAP2));
bTime = Time(strcmp(MacTransmitter, ExpBSSIDAP1) | strcmp(MacTransmitter, ExpBSSIDAP2));
bAp = zeros(length(bBSSID), 1);
bAp(strcmp(bBSSID, ExpBSSIDAP1)) = 1;
bAp(strcmp(bBSSID, ExpBSSIDAP2)) = 2;
beacons = [bNo bTime bAp bRSSI];
% get beacons of both APs, excluding the rest
beacons_ap1 = beacons(beacons(:, 3) == 1, :);
beacons_ap2 = beacons(beacons(:, 3) == 2, :);

% Calculate time in reassociating with other AP
% 1st column: packet no. before AP change
apChange = find(diff(pAp));
if ~isempty(apChange)
    for i=1:size(apChange, 1)
        i_lower = apChange(i, 1);
        i_upper = i_lower + 1;
        time_lower = pTime(i_lower);
        time_upper = pTime(i_upper);
        % 2nd column: start of reassociation
        apChange(i, 2) = time_lower;
        % 3nd column: reassociation time
        apChange(i, 3) = time_upper - time_lower;
    end
end

window_size = 20;
figure(20)
% AP1 is the only one emitting
% Capturing a few beacons from AP1 means the STA performed the roaming and
% scanned multiple channels. AP1 was emitting in one of those channels
if isempty(beacons_ap2) || size(beacons_ap2, 1) < window_size
    plot(beacons_ap1(:, 2), tsmovavg(beacons_ap1(:, 4), 's', window_size, 1), 'b');
    leg = legend('AP1');
% AP2 is the only one emitting
elseif isempty(beacons_ap1) || size(beacons_ap1, 1) < window_size
    plot(beacons_ap2(:, 2), tsmovavg(beacons_ap2(:, 4), 's', window_size, 1), 'r');
    leg = legend('AP2');
% both APs emitting
else
    plot(beacons_ap1(:, 2), tsmovavg(beacons_ap1(:, 4), 's', window_size, 1), 'b', beacons_ap2(:, 2), tsmovavg(beacons_ap2(:, 4), 's', window_size, 1), 'r');
    leg = legend('AP1', 'AP2');
end
set(gca, 'FontName', 'Arial');
set(gca, 'FontSize', 12);
title('RSSI from both APs');
set(leg, 'location', 'best');
ylim([y_axis_rssi_lower y_axis_rssi_upper]);
xlim([x_axis_lower x_axis_upper]);
xlabel('Time (s)');
ylabel('RSSI (dBm)');
fig = gcf;
saveas(fig, strcat(filename_no_ext, '_rssi_both'), figs_ext);

packets_ap1 = packets(packets(:, 3) == 1, :);
packets_ap2 = packets(packets(:, 3) == 2, :);
figure(21)
% full time connected to AP1
if isempty(packets_ap2)
    plot(packets_ap1(:, 2), tsmovavg(packets_ap1(:, 4), 's', window_size, 1), 'b');
    leg = legend('AP1');
% full time connected to AP2
elseif isempty(packets_ap1)
    plot(packets_ap2(:, 2), tsmovavg(packets_ap2(:, 4), 's', window_size, 1), 'r');
    leg = legend('AP2');
% connected to both APs
else
    plot(packets_ap1(:, 2), tsmovavg(packets_ap1(:, 4), 's', window_size, 1), 'b', packets_ap2(:, 2), tsmovavg(packets_ap2(:, 4), 's', window_size, 1), 'r');
    leg = legend('AP1', 'AP2');
end
set(gca, 'FontName', 'Arial');
set(gca, 'FontSize', 12);
title('RSSI from connected AP');
set(leg, 'location', 'best');
ylim([y_axis_rssi_lower y_axis_rssi_upper]);
xlim([x_axis_lower x_axis_upper]);
xlabel('Time (s)');
ylabel('RSSI (dBm)');
fig = gcf;
saveas(fig, strcat(filename_no_ext, '_rssi_connected'), figs_ext);

figure(22)
plot(packetsRxSort(:, 2), pdr(:, 1), 'b');
set(gca, 'FontName', 'Arial');
set(gca, 'FontSize', 12);
title('Packet Delivery Ratio (PDR)');
ylim([y_axis_pdr_lower y_axis_pdr_upper]);
xlim([x_axis_lower x_axis_upper]);
xlabel('Time (s)');
ylabel('Packet Delivery Ratio (%)');
fig = gcf;
saveas(fig, strcat(filename_no_ext, '_pdr'), figs_ext);

figure(23)
[hAx, hLine1, hLine2] = plotyy(packetsRxSort(:, 2), iat(:, 1), packetsRxSort(:, 2), packetsLostSum(:, 1));
set(hAx(1), 'FontName', 'Arial');
set(hAx(2), 'FontName', 'Arial');
set(hAx(1), 'FontSize', 12);
set(hAx(2), 'FontSize', 12);
title('Inter Arrival Time & Packet loss');
set(hAx(1), 'ylim', [y_axis_iat_lower y_axis_iat_upper]);
set(hAx(2), 'ylim', [y_axis_packet_loss_lower y_axis_packet_loss_upper]);
set(hAx(1), 'xlim', [x_axis_lower x_axis_upper]);
set(hAx(2), 'xlim', [x_axis_lower x_axis_upper]);
set(hAx(1), 'YTick', [y_axis_iat_lower:y_axis_iat_interval:y_axis_iat_upper]);
set(hAx(2), 'YTick', [y_axis_packet_loss_lower:y_axis_packet_loss_interval:y_axis_packet_loss_upper]);
set(hLine1, 'Color', 'b');
set(hLine2, 'Color', 'r');
set(hAx(1), 'ycolor', 'b');
set(hAx(2), 'ycolor', 'r');
xlabel(hAx(1), 'Time (s)');
ylabel(hAx(1), 'Inter Arrival Time (ms)');
ylabel(hAx(2), 'Cumulative number of packets lost');
fig = gcf;
saveas(fig, strcat(filename_no_ext, '_iat_and_packet_loss'), figs_ext);

figure(24)
boxplot(packetsLost(:, 2));
grid on;
set(gca, 'FontName', 'Arial');
set(gca, 'FontSize', 12);
set(gca,'xticklabel',{[]})
title('Lost Packets Distribution');
ylim([x_axis_lower x_axis_upper]);
ylabel('Time (s)');
fig = gcf;
saveas(fig, strcat(filename_no_ext, '_lost_packets_distribution'), figs_ext);

disp(['Percentage of packets lost: ' num2str(packetsLostPctg) '% (' num2str(size(packetsLost, 1)) ' out of ' num2str(size(packetsTxSortIds, 1)) ')']);
for i=1:size(apChange, 1)
    disp(['AP change #', num2str(i), ' started at time ', num2str(apChange(i, 2)), ' s and took ', num2str(1000*apChange(i, 3)), ' ms']);
end