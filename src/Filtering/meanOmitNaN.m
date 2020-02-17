function data = meanOmitNaN(data)
%wrapper for mean function with 'omitnan' parameter
data = mean(data,'omitnan');