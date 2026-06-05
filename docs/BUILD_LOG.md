# Docker no Samsung A730F (jackpot2lte) — Diário de Bordo Completo

**Data:** 04-05 Junho 2026  
**Dispositivo:** Samsung Galaxy A8 2018 (SM-A730F / codename jackpot2lte)  
**SoC:** Exynos 7885 (ARM64/aarch64)  
**Kernel:** Linux 4.4.177 (build #7 final)  
**Docker:** 27.3.1 oficial aarch64  
**Objetivo:** Rodar Docker nativamente no celular  
**Resultado:** ✅ **SUCESSO — hello-world rodando!**

---

## 1. Análise Inicial do Ambiente

### Arquivos em `~/Downloads/`
```
kernel_jackpotlte/          ← Fonte do kernel (4.4.177 Quantum Quack)
Vendor-Quack_V2.6.zip       ← Vendor GSI (430MB descompactado)
boot_docker_v2.img          ← Boot "patcheado" pronto
boot_original.img           ← Boot stock original
boot_twrp_backup.img        ← Backup TWRP do boot funcional
docker-aarch64/docker/      ← Binários Docker pré-compilados
gcc-linaro-4.9.4-...        ← Toolchain (baixado depois)
TrebleCreator-A730F.zip     ← Reparticionador
TWRP-3.3.0-jackpot2lte-Treble.img ← Recovery
odin4 / odin.zip            ← Ferramentas de flash
A730F U7 ROOT.zip           ← Magisk + Odin
docker-patched              ← Binário Docker alternativo (corrompido)
```

### Análise da Kernel
- **Versão:** 4.4.177, nome: *Blurry Fish Butt*
- **Defconfig stock:** `exynos7885-jackpot2lte_defconfig`
- **Defconfig Docker:** `exynos7885-jackpot2lte_docker_defconfig`
- **Build script:** `cronos.sh` (por BlackMesa/AnanJaser1211/Prashantp01)
- **Toolchain original esperado:** GCC Linaro 4.9.4 aarch64
- **Toolchain no sistema:** GCC 16.1.1 (Fedora 44) — **incompatível** com kernel 4.4
- **Status:** Kernel JÁ compilado (`vmlinux` 214MB, `Image.gz-dtb` 9.5MB)

### Patches Docker vs Stock (diff do defconfig)
```
CONFIG_CGROUP_PIDS    n → y
CONFIG_CGROUP_DEVICE  n → y
CONFIG_USER_NS        n → y   ← causa boot loop em Samsung!
CONFIG_BRIDGE         n → y
CONFIG_VETH           n → y
CONFIG_OVERLAY_FS     n → y
CONFIG_BRIDGE_NETFILTER  (adicionado)
```

### Features Docker FALTANDO na kernel stock
- `IPVLAN`, `MACVLAN`, `DEVPTS_MULTIPLE_INSTANCES`
- `DM_THIN_PROVISIONING`, `BPF_SYSCALL`
- `AUTOFS4_FS`, `BRIDGE_NF_EBTABLES`, `BTRFS_FS`

---

## 2. Problema #1: GCC 4.9 não encontrado

### Diagnóstico
- Kernel compilado em 04-Jun-2026 às 22:11 com GCC 4.9
- Path no `vmlinux`: `/tmp/gcc-linaro-4.9.4-2017.01-x86_64_aarch64-linux-gnu/`
- `/tmp` foi limpo → toolchain removido
- Só havia GCC 16.1.1 instalado (incompatível com kernel 4.4)

### Makefile já tinha patches para compatibilidade
```diff
- -Werror-implicit-function-declaration
+ -Wimplicit-function-declaration
- -Werror
+ (removido)
- -Werror=implicit-int
+ =implicit-int
- -Werror=strict-prototypes
+ =strict-prototypes
- -Werror=date-time
+ =date-time
```

### DTC Makefile patches
```diff
+ -fcommon (necessário para GCC 10+ compilar o DTC)
```

### Solução
Download do GCC Linaro 4.9.4:
```
https://releases.linaro.org/components/toolchain/binaries/4.9-2017.01/aarch64-linux-gnu/
gcc-linaro-4.9.4-2017.01-x86_64_aarch64-linux-gnu.tar.xz
```
Extraído em `~/Downloads/gcc-linaro-4.9.4-2017.01-x86_64_aarch64-linux-gnu/`

`cronos.sh` atualizado:
```bash
CR_TC=/home/zn/Downloads/gcc-linaro-4.9.4-2017.01-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-
```

---

## 3. Problema #2: Boot Loop (3 causas diferentes)

### Causa 2a: Kernel comprimido (Image.gz)
- **Sintoma:** Boot loop imediato
- **Descoberta:** Bootloader Samsung Exynos **não suporta kernel comprimido** (gzip)
- **Evidência:** TWRP backup usa `Image` (22MB não comprimido), nosso boot usava `Image.gz-dtb` (9.5MB comprimido)
- **Solução:** Usar `Image` não comprimido → `cat Image > Image-dtb`

### Causa 2b: DTB junto ao kernel
- **Sintoma:** Boot loop
- **Descoberta:** Samsung Exynos usa **DTB separado**, não appended ao kernel
- **Evidência do TWRP backup:** kernel NÃO tem DTB magic (0xd00dfeed), DTB está na partição separada
- **Solução:** Boot.img sem DTB appended

### Causa 2c: DTBH + SEANDROIDENFORCE (a causa REAL)
- **Sintoma:** Boot loop
- **Descoberta ao analisar `BoardConfig.mk` do repo oficial:**
  ```makefile
  BOARD_KERNEL_SEPARATED_DT := true           # DTB separado
  TARGET_CUSTOM_DTBTOOL := dtbhtoolExynos     # Ferramenta customizada
  $(hide) echo -n "SEANDROIDENFORCE" >> $@    # Assinatura Samsung!
  ```
- **O que é DTBH:** Device Tree Blob Header — formato Samsung Exynos
  - Cabeçalho `DTBH` (4 bytes) + versão + contagem de entradas
  - Cada entrada: chip_id, platform_id, subtype, hw_rev, offset, size
  - Múltiplos DTBs empacotados, página-alinhados
- **O que é SEANDROIDENFORCE:** String mágica de 16 bytes no FINAL do boot.img
  - Bootloader Samsung verifica essa string
  - Sem ela: **boot rejeitado** → boot loop
- **Localização no boot.img:**
  1. Header (1 página = 2048 bytes)
  2. Kernel Image (não comprimido, páginas alinhadas)
  3. Ramdisk (gzip cpio, páginas alinhadas)
  4. **DTBH table** (páginas alinhadas) — nos campos `unused[0]` do header
  5. **SEANDROIDENFORCE** (16 bytes no final)
- **Solução:** Extrair DTBH do TWRP backup e remontar boot.img com estrutura correta

### Estrutura final do boot.img que FUNCIONA:
```
Offset 0x000000: Header ANDROID! (2048 bytes)
  - unused[0] = DTBH size (882688 = 0xD7800)
  - board = SRPQG24A001RU
  - cmdline = androidboot.selinux=permissive
Offset 0x000800: Kernel Image (não comprimido, ~22MB)
Offset 0x1510000: Ramdisk gzip (878KB)
Offset 0x15E8C00: DTBH table (862KB)
Offset 0x16C1800: SEANDROIDENFORCE (16 bytes) → FIM
```

### Flash correto
```bash
# Partição correta: 13500000 (NÃO 13520000!)
dd if=boot.img of=/dev/block/platform/13500000.dwmmc0/by-name/BOOT
```

---

## 4. Problema #3: CONFIG_USER_NS quebra boot

### Diagnóstico
- Kernel docker completo → **boot loop**
- Kernel stock → **boota normal**
- Desativando `CONFIG_USER_NS` → **boota normal**
- **Causa:** Samsung Knox/segurança conflita com user namespaces
- **Impacto no Docker:** Docker funciona sem USER_NS (perde `--userns-remap`)

---

## 5. Repositórios Clonados (a pedido do usuário)

### `prashantpaddune/Universal7885-P`
- Fonte do kernel para todos os Exynos 7885
- Mesmo código que `kernel_jackpotlte`
- Contém `cronos.sh` com path do toolchain original

### `prashantpaddune/android_device_samsung_jackpot2lte`
- **Device tree oficial** para A730F
- Arquivos críticos descobertos:

**`BoardConfig.mk`:**
```makefile
TARGET_KERNEL_CONFIG := exynos7885-jackpot2lte_defconfig
BOARD_KERNEL_SEPARATED_DT := true           ← DTB separado!
BOARD_KERNEL_IMAGE_NAME := Image            ← Não comprimido!
TARGET_CUSTOM_DTBTOOL := dtbhtoolExynos    ← Ferramenta DTBH
BOARD_MKBOOTIMG_ARGS := --board SRPQG24A001RU
```

**`mkbootimg.mk`:**
- `$(hide) echo -n "SEANDROIDENFORCE" >> $@` ← **ISSO era o segredo!**

**`dtbhtool/`:**
- Ferramenta que cria o formato DTBH Samsung Exynos
- Documentação do formato DTBH (layout binário completo)
- Suporte a múltiplos DTBs com chip/platform/subtype

**`recovery/root/`:**
- Ramdisk mínimo do TWRP com `fstab.samsungexynos7885`

---

## 6. Problema #4: Docker segfault (Go binary incompatível)

### Diagnóstico
- Binários `docker-aarch64/` (Go 1.26.4) → **SEGFAULT** no Android
- `strace` mostrou: `SIGSEGV si_addr=0xd27ee0` após `set_tid_address`
- `runc` do mesmo pacote → **FUNCIONA** (Go 1.26.4 também!)

### Causa
- Binários Docker do pacote `docker-aarch64/` foram **stripped** com `strip`
- Section headers removidas → Android `linker64` não consegue parsear
- `readelf` confirma: `no section header`
- Já o `runc` estava "not stripped" → funciona
- `docker-patched` tinha INTERP corrompido (interpreter = `\x03`)

### Solução
Download Docker **27.3.1** oficial (Go 1.22.7, not stripped):
```
https://download.docker.com/linux/static/stable/aarch64/docker-27.3.1.tgz
```
→ Funciona perfeitamente no Android!

---

## 7. Problema #5: TLS / CA Certificates

### Diagnóstico
- DNS resolveu, mas: `x509: certificate signed by unknown authority`
- Android não tem `/etc/ssl/certs/ca-certificates.crt`
- Mas tem certificados em `/system/etc/security/cacerts/*.0` (formato PEM)

### Solução
```bash
cat /system/etc/security/cacerts/*.0 > /data/docker/certs/ca-certificates.crt
export SSL_CERT_FILE=/data/docker/certs/ca-certificates.crt
```

---

## 8. Problema #6: Cgroups (cpuset Android)

### Diagnóstico
- Docker puxa imagem mas erro ao criar container:
  `open /sys/fs/cgroup/cpuset/docker/cpuset.cpus: no such file or directory`
- Android monta cpuset com opção `noprefix` (patch no kernel)
  - Arquivos padrão Linux: `cpuset.cpus`, `cpuset.mems`
  - Arquivos Android: `cpus`, `mems`
- Docker/runc esperam nomes padrão Linux

### Solução
**Recompilar kernel sem CONFIG_CPUSETS.**  
Docker funciona perfeitamente sem cpuset (só mostra warning).

---

## 9. Problema #7: Cgroups não montados

### Diagnóstico
```
failed to start daemon: Devices cgroup isn't mounted
```
Android não monta cgroups no layout que Docker espera (`/sys/fs/cgroup/`)

### Solução
```bash
mount -t tmpfs none /sys/fs/cgroup
for ctrl in cpu cpuacct memory devices freezer pids; do
    mkdir -p /sys/fs/cgroup/$ctrl
    mount -t cgroup -o $ctrl none /sys/fs/cgroup/$ctrl
done
```

---

## 10. Problema #8: Docker init / containerd-shim

### Diagnóstico
- `exec format error` nos binários antigos em `/system/bin`
- Binários `docker-aarch64` (incompatíveis) foram copiados lá

### Solução
```bash
rm -f /system/bin/runc /system/bin/containerd-shim-runc-v2
ln -sf /data/local/tmp/docker27/* /system/bin/
```

---

## 11. Problema #9: /run read-only

### Diagnóstico
```
mkdir /run/containerd/s: read-only file system
```
Containerd-shim tenta criar sockets em `/run` (read-only em Android)

### Descoberta
Na verdade `/` é RW: `/dev/block/mmcblk0p19 on / type ext4 (rw,...)`  
O problema era o path errado configurado no containerd.

### Solução
Configurar containerd com `--state /data/docker/containerd/state` (writable)

---

## 12. Problema #10: `docker run` falha — `can't get final child's PID from pipe: EOF`

### Diagnóstico
Erro completo: `OCI runtime create failed: runc create failed: unable to start container process: can't get final child's PID from pipe: EOF`

- runc direto → FUNCIONA (container cria, executa, sai)
- runc via Docker → FALHA (EOF no pipe)
- `hello` binary executado direto no celular → FUNCIONA (imprime mensagem)
- Significa: o binário roda, mas o namespace/clone falha

### Investigação com runc --debug
```
nsexec-1[9551]: failed to unshare remaining namespaces: Invalid argument
```
`unshare(CLONE_NEWIPC)` retornando **EINVAL** = IPC namespace não suportado.

### Causa Raiz
Docker gera OCI spec com 4 namespaces: `["pid", "mount", "uts", "ipc"]`.  
O kernel **NÃO** tinha `CONFIG_IPC_NS` ativado.

Mas por que não tava? `CONFIG_IPC_NS` depende de `CONFIG_SYSVIPC` ou `CONFIG_POSIX_MQUEUE`. Nenhum dos dois estava ativado, então `olddefconfig` removia `IPC_NS` automaticamente.

### Solução
```bash
echo "CONFIG_POSIX_MQUEUE=y" >> .config
echo "CONFIG_IPC_NS=y" >> .config
make olddefconfig && make -j$(nproc)
```
**Kernel build #7** com `IPC_NS=y` + `POSIX_MQUEUE=y`.

### Também: /run read-only
Containerd-shim tentava criar socket em `/run/containerd/s/` (read-only).  
Solução: bind mount de diretório writable.
```bash
mkdir -p /data/docker/shim_sockets
mount --bind /data/docker/shim_sockets /run/containerd/s
```

### Resultado Final
```
$ docker run --rm hello-world
Hello from Docker!
This message shows that your installation appears to be working correctly.
```
**✅ DOCKER FUNCIONANDO NO A730F!**

---

## 13. Config Final do Kernel (build #7 — FUNCIONANDO)

Defconfig base: `exynos7885-jackpot2lte_docker_nouserns_defconfig`  
Modificações manuais:

```ini
# Docker patches (do defconfig)
CONFIG_CGROUP_PIDS=y
CONFIG_CGROUP_DEVICE=y
CONFIG_BRIDGE=y
CONFIG_VETH=y
CONFIG_OVERLAY_FS=y
CONFIG_BRIDGE_NETFILTER=y

# Docker patches (adicionados manualmente)
CONFIG_POSIX_MQUEUE=y        ← Dependência do IPC_NS
CONFIG_IPC_NS=y              ← O ÚLTIMO BUG! Docker exige IPC namespace

# Desativados (incompatíveis com Samsung/Android)
# CONFIG_USER_NS is not set   ← Quebra boot (Knox)
# CONFIG_CPUSETS is not set   ← Android usa noprefix (incompatível)

# Já existentes no stock
CONFIG_SECCOMP=y
CONFIG_SECCOMP_FILTER=y
CONFIG_NAMESPACES=y
CONFIG_CGROUPS=y
CONFIG_FAIR_GROUP_SCHED=y
```

### Build command final
```bash
export CROSS_COMPILE=~/Downloads/gcc-linaro-4.9.4-2017.01-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-
export ANDROID_MAJOR_VERSION=p
export PLATFORM_VERSION=9

make exynos7885-jackpot2lte_docker_nouserns_defconfig
sed -i 's/CONFIG_CPUSETS=y/# CONFIG_CPUSETS is not set/' .config
echo "CONFIG_POSIX_MQUEUE=y" >> .config
echo "CONFIG_IPC_NS=y" >> .config
make olddefconfig
make -j$(nproc)

# Criar boot.img Samsung
python3 tools-pc/mkboot_samsung.py \
    arch/arm64/boot/Image \
    boot/ramdisk_original.gz \
    boot/boot_dtbh.bin \
    boot/boot.img
```

---

## 14. Estrutura de Arquivos Final

```
~/Downloads/docker_a730f/          ← ★ Repo Git principal
├── README.md                       ← Guia de uso rápido
├── .gitignore
├── boot/
│   ├── boot.img                    ← ★ Kernel Docker final (flashar este!)
│   ├── backup_twrp_boot.img        ← Backup TWRP do boot funcional
│   ├── boot_dtbh.bin               ← DTBH Samsung extraído
│   └── ramdisk_original.gz         ← Ramdisk do TWRP backup
├── kernel-config/
│   ├── 01-stock_docker.defconfig   ← Docker patches originais
│   ├── 02-docker_nouserns.defconfig ← Docker sem USER_NS
│   ├── 03-final_running.config     ← Config final build #7
│   └── cronos.sh                   ← Build script
├── tools-phone/                    ← Scripts pro celular (/sdcard/Docker/)
│   ├── start.sh                    ← Inicia Docker (cgroups+containerd+dockerd)
│   ├── stop.sh                     ← Para Docker
│   ├── repair.sh                   ← Repara symlinks/certs
│   └── docker-alias.sh             ← Alias: "docker" → socket correto
├── tools-pc/                       ← Scripts pro Linux
│   ├── build_kernel.sh             ← Compila kernel
│   ├── flash_boot.sh               ← Flasheia boot via ADB
│   ├── deploy_docker.sh            ← Envia Docker 27.3.1 pro celular
│   └── mkboot_samsung.py           ← Cria boot.img com DTBH+SEANDROIDENFORCE
├── docs/
│   └── BUILD_LOG.md                ← ★ Este documento
├── docker-binaries/                ← docker-27.3.1-aarch64.tgz
└── logs-saved/                     ← Logs de debug

~/Downloads/kernel_jackpotlte/      ← Fonte do kernel (build directory)
├── arch/arm64/boot/Image           ← Kernel compilado (não comprimido)
├── cronos.sh                       ← Build script original
└── .config                         ← Config atual

Celular:
├── /data/local/tmp/docker27/       ← Binários Docker 27.3.1
├── /data/docker/                   ← Dados Docker (containers, imagens)
└── /sdcard/Docker/                 ← Scripts + README + boot.img
    ├── tools-phone/
    ├── README.md
    └── boot.img
```

---

## 15. Checklist Final — Tudo Funcionando

| # | Item | Status |
|---|---|---|
| 1 | Kernel compilado (GCC 4.9) | ✅ |
| 2 | Boot com DTBH + SEANDROIDENFORCE | ✅ |
| 3 | OVERLAY_FS, BRIDGE, VETH | ✅ |
| 4 | CGROUP_PIDS, CGROUP_DEVICE | ✅ |
| 5 | SECCOMP | ✅ |
| 6 | POSIX_MQUEUE | ✅ |
| 7 | IPC_NS (o último bug!) | ✅ |
| 8 | Boot sem USER_NS (não quebra Samsung) | ✅ |
| 9 | Boot sem CPUSETS (não conflita Android) | ✅ |
| 10 | Docker 27.3.1 binary compatível | ✅ |
| 11 | CA certificates | ✅ |
| 12 | DNS (8.8.8.8) | ✅ |
| 13 | Cgroups montados (/sys/fs/cgroup/*) | ✅ |
| 14 | dockerd iniciando | ✅ |
| 15 | containerd iniciando | ✅ |
| 16 | docker pull (hello-world) | ✅ |
| 17 | docker run container | ✅ |
| 18 | hello-world output | ✅ |

---

## 16. Lições Aprendidas (13 no total)

1. **Nunca usar kernel comprimido em Samsung Exynos** — bootloader não suporta gzip
2. **SEANDROIDENFORCE é obrigatório** — 16 bytes mágicos no final do boot.img
3. **DTBH é formato proprietário Samsung** — tabela de DTB com header `DTBH`, campos `unused[0]` e `unused[1]` no header
4. **BoardConfig.mk do device tree oficial tem TODAS as respostas** — `prashantpaddune/android_device_samsung_jackpot2lte`
5. **CONFIG_USER_NS quebra boot em Samsung** (Knox/Secure OS conflita)
6. **CONFIG_CPUSETS do Android é incompatível** com Docker (kernel patch `noprefix` renomeia `cpuset.cpus` → `cpus`)
7. **Binários Go stripped quebram no Android** — `linker64` rejeita ELFs sem section headers
8. **Android monta cgroups em paths não-padrão** — precisa remontar em `/sys/fs/cgroup/`
9. **Toolchain precisa ser compatível** — GCC 16 não compila kernel 4.4 (GCC 4.9 requerido)
10. **O path da partição boot é `13500000.dwmmc0`, não `13520000`**
11. **CONFIG_IPC_NS depende de CONFIG_POSIX_MQUEUE ou CONFIG_SYSVIPC** — se nenhum estiver ativado, IPC_NS é silenciosamente removido pelo `olddefconfig`
12. **Docker 27.3.1 (Go 1.22.7) funciona no Android, binários Go 1.26.4+ dão segfault** no kernel 4.4
13. **`/run/containerd/s` precisa ser writable** — bind mount de `/data/docker/shim_sockets` resolve
