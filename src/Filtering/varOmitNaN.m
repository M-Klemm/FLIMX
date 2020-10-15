function data = varOmitNaN(data)
%wrapper for var function with 'omitnan' parameter
data = var(data,'omitnan');