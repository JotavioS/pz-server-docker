# Project Zomboid Dedicated Server Docker (x86_64 & arm64)

Este repositório fornece configurações Docker completas e estruturadas do zero para executar um servidor dedicado de **Project Zomboid** nas arquiteturas **x86_64** (Intel/AMD) e **arm64** (Apple Silicon, Raspberry Pi, VMs do Oracle Cloud Ampere, etc.).

Ambos os setups são construídos sob bases consistentes utilizando **Ubuntu 22.04** como imagem base e o usuário não-privilegiado `steam`.

## Estrutura do Repositório

O projeto é dividido em dois diretórios correspondentes a cada arquitetura:

*   **`x86_64/`**: Configuração nativa construída a partir do Ubuntu 22.04, ideal para computadores e servidores padrão Intel ou AMD.
*   **`arm64/`**: Configuração baseada em emulação de alto desempenho utilizando **Box86** (para a SteamCMD de 32 bits) e **Box64** (para a máquina virtual Java de 64 bits do Project Zomboid).

---

## Configuração do Servidor (`.env`)

A configuração do servidor é feita de forma idêntica em ambas as arquiteturas através de arquivos de ambiente.

1. Acesse a pasta correspondente à sua arquitetura (`x86_64` ou `arm64`).
2. Copie o arquivo `.env.template` para `.env`:
   ```bash
   cp .env.template .env
   ```
3. Edite o arquivo `.env` para ajustar os parâmetros do seu servidor:
   *   **`ADMINPASSWORD`**: (Obrigatório na primeira inicialização) Defina a senha do administrador do servidor.
   *   **`MEMORY`**: RAM alocada para o servidor (ex: `4096m` ou `8096m`).
   *   **`NOSTEAM`**: Defina como `True` se desejar permitir a conexão de clientes não oficiais/não-Steam.
   *   **`MOD_IDS`** e **`WORKSHOP_IDS`**: IDs dos mods e itens do Workshop separados por ponto e vírgula.

---

## Como Executar

### Opção 1: x86_64 (Nativo Intel/AMD)

Entre no diretório e inicialize o container:
```bash
cd x86_64
docker compose up -d --build
```

### Opção 2: arm64 (Emulado via Box86/Box64)

Esta imagem irá compilar as ferramentas de tradução de instruções **Box86** e **Box64** diretamente no container para rodar o jogo com desempenho próximo ao nativo (muito superior ao QEMU).

Entre no diretório e inicialize o container:
```bash
cd arm64
docker compose up -d --build
```
*Nota: A compilação dos emuladores e o download inicial dos arquivos do jogo podem levar de 5 a 10 minutos na primeira execução.*

---

## Conectividade e Portas Requeridas

As portas já vêm pré-configuradas nos arquivos `docker-compose.yml` para suportar tanto clientes Steam quanto não Steam.

Certifique-se de liberar/redirecionar as seguintes portas no firewall do seu sistema e roteador:

### Portas Comuns (Steam & Geral)
*   `16261/UDP` — Porta de rede de comunicação do servidor do jogo.
*   `27015/TCP` — Porta opcional para RCON (gerenciamento remoto).

### Portas para Clientes Não-Steam (Conexão Direta)
Se você definiu `NOSTEAM=True` no seu `.env`, o servidor necessita das seguintes portas abertas:
*   `8766/UDP` e `8767/UDP` — Portas query de autenticação.
*   `16262-16272/TCP` — Intervalo de portas TCP de conexão direta. *Cada jogador conectado simultaneamente consome uma porta desse intervalo (ex: o intervalo padrão de 11 portas atende até 11 jogadores simultâneos).*

---

## Como funciona a Emulação ARM64

Devido à ausência de compilação nativa de Project Zomboid para processadores ARM, a pasta `arm64/` utiliza a seguinte estratégia de virtualização:
1. **Compilação sob Medida**: Box86 e Box64 são compilados sob medida otimizados para arquiteturas ARMv8-A.
2. **SteamCMD (32-bit x86)**: Traduzido via **Box86** com suporte a bibliotecas nativas de 32 bits (`armhf`) instaladas no container.
3. **Project Zomboid (64-bit x86_64)**: Traduzido via **Box64** interceptando as chamadas da JRE (Java Runtime Environment) de 64 bits do jogo.
4. **Resiliência (Auto-Cura)**: O script `entry.sh` na pasta `arm64/` monitora a integridade dos binários. Se uma atualização da SteamCMD ou do próprio jogo restaurar os executáveis originais x86 de Java ou SteamCMD, o script recria automaticamente os wrappers de tradução durante o boot.