close all;

% filenames = {'diff_ch_no_moving.csv', 'diff_ch_moving.csv',...
%             'same_ch_no_moving.csv', 'same_ch_moving.csv',...
%             'wds_same_ch_no_moving_masterAP.csv', 'wds_same_ch_no_moving_slaveAP.csv',...
%             'wds_same_ch_moving.csv', 'realistic_same_ch_moving.csv'};

for idx = 1:numel(filenames)
    clearvars -except filenames idx;
    
    curr_filename = filenames{:,idx};

    % avoid first row, which contains column tags
    fileID = fopen(curr_filename, 'r');
    % no,wlan.sa,wlan.da,wlan.ta,wlan.ra,wlan.bssid,Time,ip.src,ip.dst,protocol,length,info,wlan.fc.retry,.radiotap.datarate,wlan.rssi,data.data
    packets = textscan(fileID, '%q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q %q', 'Delimiter', ',', 'HeaderLines', 1);
    fclose(fileID);

    No = packets{:, 1};
    MacSource = packets{:, 2};
    MacDestination = packets{:, 3};
    MacTransmitter = packets{:, 4};
    MacReceiver = packets{:, 5};
    BSSID = packets{:, 6};
    Time = packets{:, 7};
    IPSrc = packets{:, 8};
    IPDst = packets{:, 9};
    Protocol = packets{:, 10};
    Length = packets{:, 11};
    Info = packets{:, 12};
    Retry = packets{:, 13};
    Rate = packets{:, 14};
    RSSI = packets{:, 15};
    Channel = packets{:, 16};
    Data = packets{:, 17};

    % String to int
    No = [cellfun(@str2num, No)];
    
    % String to double
    % first Time measure will be 0, the remaining Times will be relative to
    % that one
    Time = [cellfun(@str2num, Time)];
    Time = Time - min(Time);

    % String to int
    Length = [cellfun(@str2num, Length)];

    % String to boolean
    Retry = strrep(Retry, 'Frame is not being retransmitted', '0');
    Retry = strrep(Retry, 'Frame is being retransmitted', '1');
    Retry = [cellfun(@str2num, Retry)];

    % Decimals with dot instead of comma
    Rate = strrep(Rate, ',', '.');
    Rate = [cellfun(@str2num, Rate)];

    % String to int
    RSSI = strrep(RSSI, ' dBm', '');
    RSSI = [cellfun(@str2num, RSSI)];
    
    % String to double
    Data = [cellfun(@customhex2num, Data)];
    
    clearvars ans packets fileID;
    % Save variables into .mat file
    save(strrep(curr_filename, '.csv', '.mat'));
end