az login
az account set --subscription "ME-MngEnvMCAP675646-emknafo-1"
az webapp up --runtime PYTHON:3.9 --sku B1 --logs