function data = medianOmitNaN(data)
%wrapper for median function with 'omitnan' parameter
data = median(data,'omitnan');