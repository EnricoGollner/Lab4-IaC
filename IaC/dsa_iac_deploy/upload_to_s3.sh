# Comando que utiliza o AWS CLI, instalado no docker,
# para copiar os arquivos da pasta "dsa_ml_app" para o bucket S3 criado na nuvem
# O --recursive é para que copie o conteúdo dentro da pasta, além da pasta em si.
aws s3 cp /iac/dsa_ml_app s3://dsa-727646479757-bucket/ --recursive
