# Comando que utiliza o AWS CLI, instalado no docker,
# para remover o conteúdo do bucket S3 para podermos destruí-lo.
# O --recursive é para que delete o conteúdo dentro da pasta, além da pasta em si.
aws s3 rm s3://dsa-727646479757-bucket --recursive