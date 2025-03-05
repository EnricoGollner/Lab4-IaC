# Visão geral:
# Vamos ter os arquivos em um bucket S3, a aplicação em um servidor EC2
# E assim, vamos subir a infraestrutura permitindo que os 2 serviços se comuniquem.

provider "aws" {
  region = "us-east-2"
}

resource "aws_s3_bucket" "dsa_bucket_flask" {
  bucket = "dsa-727646479757-bucket" 

  tags = {
    Name        = "DSA Bucket"
    Environment = "Lab4"
  }

  provisioner "local-exec" {
    # Executando o script .sh, que vai copiar os arquivos da máquina local (docker)
    # para o bucket S3 criado na nuvem.
    # O Terraform não permite executarmos direto no script comandos de cópia, O COMANDO PELO TERRAFORM
    # Mas podemos executar utilizando este provisioner de execução local.
    # Com path.module, estamos dizendo que o script está no caminho do módulo, que é o próprio diretório/pasta
    command = "${path.module}/upload_to_s3.sh"
  }

  # Quando executarmos o "terraform destroy",
  # precisamos remover o conteúdo do bucket antes de destruí-lo
  # O comando diz: "quando executar o destroy, vamos executar primeiro o seguinte comando"
  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/remove_s3_content.sh"
  }
}

resource "aws_instance" "dsa_ml_api" {
  ami = "ami-0a0d9cf81c479446a"  
  instance_type = "t2.micro"

  # IAM
  iam_instance_profile = aws_iam_instance_profile.ec2_s3_profile.name

  # Security Groups
  vpc_security_group_ids = [aws_security_group.dsa_ml_api_sg.id]

  # Script de inicialização
  # Preparando o servidor na nuvem
  # Com o "sudo aws s3 sync ...", estamos copiando todo o conteúdo do bucket para a pasta "dsa_ml_app"

  # Explicando a execução do comando do WSGI utilizado, o gunicorn:
  # "nohup gunicorn -w 4 -b 0.0.0.0:5000 app:app &"
  # gunicorn é o comando
  # -w é para definirmos a quantidade de workers, no caso, queremos 4 processos
  # (então de fato, teremos 4 processos concorrentes tratando as demandas, as conexões que serão feitas na nossa aplicação)
  # "-b 0.0.0.0:5000" estamos dizendo que vamos inicializar nossa aplicação para atender em qualquer endereço IP do meu servidor
  # e a porta que iremos utilizar é a 5000
  # Por fim, vamos dizer o seguinte com "app:app"
  # Quero uma app a ser executada. O nome da app aqui é "app.py", ou seja, do lado esquerdo é o nome do arquivo e
  # do lado direito, o objeto da aplicação WSGI,
  # que no caso, é o flask, o objeto é a variável app que recebe a instância do flask
  # Ou seja, o que o gunicorn está fazendo é executando o script python cujo nome é "app.py"
  # "No 'app.py', execute o objeto 'app'"
  # Só que, se somente executássemos o gunicorn, ele vai ficar com o terminal aberto e não queremos isso,
  # então vamos colocar o comando do gunicorn para rodar em background, utilizando o "nohup".
  # "nohup" é um app que vai pegar o comando que passamos para ele e vai colocar no "&", que é o background (segundo plano)
  # e vai te dar um arquivo de log, onde podemos acompanhar tudo o que está acontecendo em background (segundo plano)
  user_data = <<-EOF
                #!/bin/bash
                sudo yum update -y
                sudo yum install -y python3 python3-pip awscli
                sudo pip3 install flask joblib scikit-learn numpy scipy gunicorn
                sudo mkdir /dsa_ml_app
                sudo aws s3 sync s3://dsa-727646479757-bucket /dsa_ml_app
                cd /dsa_ml_app
                nohup gunicorn -w 4 -b 0.0.0.0:5000 app:app &
              EOF

  tags = {
    Name = "DSAFlaskApp"
  }
}

resource "aws_security_group" "dsa_ml_api_sg" {
  name        = "dsa_ml_api_sg"
  description = "Security Group for Flask App in EC2"

  # Porta padrão do HTTP
  ingress {
    description = "Inbound Rule 1"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Porta na qual vai rodar a nossa aplicação
  ingress {
    description = "Inbound Rule 2"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Porta do SSH (Vamos acessar a instância EC2 no terminal no navegador)
  ingress {
    description = "Inbound Rule 3"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regra de saída para qualquer porta e endereço na internet conseguir acessar
  egress {
    description = "Outbound Rule"
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Vamos usar os 2 serviços acima da AWS, o S3 e o EC2
# Para que os 2 serviços possam se comunicar, precisamos configurar a permissão,
# Nesse caso, utilizaremos um 3° seriço AWS, que é o IAM
# Com o IAM, criaremos um perfil de acesso, que vai permitir que o S3 e o EC2 se comuniquem

# Primeiro, definimos o IAM role, que é a função de acesso
resource "aws_iam_role" "ec2_s3_access_role" {
  name = "ec2_s3_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17", # Padrão de política da AWS - A AWS gerencia os padrões de políticas via data
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# Depois, iremos criar uma IAM policy, que é a política - o que eu posso fazer na S3
resource "aws_iam_role_policy" "s3_access_policy" {
  # Nome da política
  name = "s3_access_policy"
  # Role criada no recurso definido acima
  role = aws_iam_role.ec2_s3_access_role.id

  # Chamando uma política padrão como partida e então customizando a mesma
  # Dizendo "No S3, permito pegar objetos, gravar objetos e listar objetos do meu bucket"
  # O detalhe é que as definições feitas aqui servem apenas para o nosso bucket criado aqui,
  # pois definimos isso no "Resource"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Effect = "Allow",
        Resource = [
          "${aws_s3_bucket.dsa_bucket_flask.arn}/*",
          "${aws_s3_bucket.dsa_bucket_flask.arn}"
        ]
      },
    ]
  })
}

# Definimos a instance profile para ser utilizada na criação da instância EC2
# Por fim, criamos o nosso profile.
# Então criamos a função (aws_iam_role), a política (aws_iam_role_policy) e acoplo tudo isso a um profile,
# que será associado a instância EC2, para que ela tenha as permissões criadas e acopladas ao profile,
# podendo, nesse caso, fazer a leitura, a gravação e listar qualquer coisa dentro do meu bucket
resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "ec2_s3_profile"
  role = aws_iam_role.ec2_s3_access_role.name
}
