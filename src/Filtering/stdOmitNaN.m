function data = stdOmitNaN(data)
%wrapper for std function with 'omitnan' parameter
data = std(data,'omitnan');