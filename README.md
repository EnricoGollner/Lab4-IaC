# Pós-Graduação em Engenharia de Dados - Automação de Deploy de Infraestrutura na AWS com Terraform - Parte 1

Este projeto tem como objetivo automatizar o processo de deploy de infraestrutura na AWS utilizando o Terraform. Siga os passos abaixo para configurar e executar o ambiente localmente.

## 1. Preparação do Ambiente

Abra este diretório/repositório no terminal ou prompt de comando.

## 2. Construção da Imagem Docker

Para criar a imagem Docker, execute o comando abaixo no terminal:

```bash
docker build -t dsa-terraform-image:lab4 .
```

## 3. Criação do Container Docker
Para criar e rodar o container Docker, execute o seguinte comando:

```bash
docker run -dit --name dsa-lab4 -v ./IaC:/iac dsa-terraform-image:lab4 /bin/bash
```
**Nota:**  No Windows, substitua ./IaC pelo caminho completo da pasta. Por exemplo, para o caminho "C:\DSA\Cap08\IaC", use:

```bash
docker run -dit --name dsa-lab4 -v C:\DSA\Cap08\IaC:/iac dsa-terraform-image:lab4 /bin/bash
```

## 4. Verifique as versões do Terraform e do AWS CLI com os comandos abaixo

```bash
terraform version
aws --version
```
---
#### * ATENÇÃO: VOCÊ PRECISA TER O [ANACONDA PYTHON](https://www.anaconda.com/) INSTALADO LOCALMENTE PARA FAZER O DEPLOY LOCAL DO MODELO DE MACHINE LEARNING.