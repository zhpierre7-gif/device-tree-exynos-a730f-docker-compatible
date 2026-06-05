# A730F Docker Kernel — Android Rodando Docker Nativo

**Dispositivo:** Samsung Galaxy A8 2018 (SM-A730F / jackpot2lte)  
**SoC:** Exynos 7885 (ARM64) | **Kernel:** Linux 4.4.177  
**Docker:** v27.3.1 (oficial aarch64) | **GSI:** Android 11 treble_arm64_bvS

---

## Estrutura do Projeto

```
docker_a730f/
├── README.md                    ← Este arquivo
├── boot/                        ← Imagens de boot
│   ├── boot.img                 ← ★ FLASHAR ESTE (kernel Docker final)
│   ├── backup_twrp_boot.img     ← Boot original do TWRP (referência)
│   ├── boot_dtbh.bin            ← DTBH Samsung extraído
│   └── ramdisk_original.gz      ← Ramdisk original
├── kernel-config/               ← Configs da kernel
│   ├── 01-stock_docker.defconfig      ← Docker completo (quebra boot)
│   ├── 02-docker_nouserns.defconfig   ← Docker sem USER_NS
│   ├── 03-final_running.config        ← Config rodando AGORA no celular
│   └── cronos.sh                      ← Script de build
├── tools-phone/                 ← Scripts pro celular
│   ├── start.sh                 ← Inicia Docker (cgroups + containerd + dockerd)
│   ├── stop.sh                  ← Para Docker
│   ├── repair.sh                ← Repara symlinks/certs após reboot
│   └── docker-alias.sh          ← Alias pra usar "docker" direto
├── tools-pc/                    ← Scripts pro Linux
│   ├── build_kernel.sh          ← Compila kernel do zero
│   ├── flash_boot.sh            ← Flasheia boot via ADB
│   ├── deploy_docker.sh         ← Envia binários Docker pro celular
│   └── mkboot_samsung.py        ← Script Python que cria boot.img Samsung
├── docker-binaries/             ← Binários Docker 27.3.1 aarch64
│   └── docker-27.3.1-aarch64.tgz
├── docs/                        ← Documentação detalhada
│   └── BUILD_LOG.md             ← ★ Diário de bordo COMPLETO
└── logs-saved/                  ← Logs de debug salvos
```

---

## Como Usar (Passo a Passo)

### Setup Inicial (PC → Celular)

```bash
# 1. Flash kernel Docker
cd docker_a730f
bash tools-pc/flash_boot.sh        # Flasheia e reinicia

# 2. Envia Docker pro celular
bash tools-pc/deploy_docker.sh     # Copia binários Docker 27.3.1
```

### No Celular (via adb shell ou terminal root)

```bash
# 1. Iniciar Docker
su -c 'sh /sdcard/Docker/start.sh'

# 2. Criar alias (uma vez por sessão)
source /sdcard/Docker/docker-alias.sh

# 3. Testar
docker version
docker pull alpine
docker run --rm alpine echo "DOCKER NO CELULAR!"
```

### Flash Manual (TWRP)

```
Install → Install Image → boot.img → Boot → Swipe
```

---

## O que o Kernel Docker Tem

| Feature | Stock | Docker |
|---|---|---|
| OVERLAY_FS | ❌ | ✓ |
| BRIDGE | ❌ | ✓ |
| VETH | ❌ | ✓ |
| CGROUP_PIDS | ❌ | ✓ |
| CGROUP_DEVICE | ❌ | ✓ |
| BRIDGE_NETFILTER | ❌ | ✓ |
| SECCOMP | ✓ | ✓ |
| USER_NS | ❌ | ❌ (quebra boot Samsung) |
| CPUSETS | ✓ | ❌ (incompatível Android) |

---

## Limitações

- Sem rede bridge (iptables não configurado)
- Storage: VFS (overlay2 incompatível com Android)
- Sem user namespaces (Knox conflita)
- Containers só com `--network=none`

---

## Build da Kernel (do zero)

```bash
# Requer: GCC Linaro 4.9.4 aarch64
# Baixar: https://releases.linaro.org/components/toolchain/binaries/4.9-2017.01/aarch64-linux-gnu/

cd docker_a730f
bash tools-pc/build_kernel.sh
# Output: ~/Downloads/kernel_jackpotlte/arch/arm64/boot/Image

# Depois usar mkboot_samsung.py pra criar boot.img com DTBH + SEANDROIDENFORCE
```

---

## Comandos Úteis

```bash
# Status
docker info
docker ps

# Pull + run
docker run --rm alpine uname -a

# Shell no container
docker run -it --rm alpine sh

# Limpeza
docker system prune -af

# Logs
cat /data/docker/dockerd.log
cat /data/docker/containerd.log

# Debug cgroups
mount | grep cgroup
ls /sys/fs/cgroup/*/
```

---

## Erros Conhecidos e Soluções

| Sintoma | Causa | Solução |
|---|---|---|
| Boot loop ao flashar | Sem DTBH + SEANDROIDENFORCE | Usar `boot/boot.img` deste repo |
| Boot loop (kernel comprimido) | Image.gz não suportado | Usar Image sem compressão |
| `docker: segfault` | Binário stripped da pasta errada | Usar Docker 27.3.1 oficial |
| `cannot connect to daemon` | Socket sem permissão | `su -c 'chmod 666 /data/local/tmp/docker.sock'` |
| `cgroup isn't mounted` | Android não monta cgroups padrão | Rodar `start.sh` primeiro |
| `x509: certificate signed by unknown` | Sem CA certs | `repair.sh` reconstrói |
| `can't find runc binary` | Symlinks quebrados após reboot | `repair.sh` recria symlinks |

---

## Créditos

- **Kernel:** Quantum Quack (BlackMesa/AnanJaser1211/Prashantp01)
- **Device Tree:** [prashantpaddune/android_device_samsung_jackpot2lte](https://github.com/prashantpaddune/android_device_samsung_jackpot2lte)
- **Kernel Source:** [prashantpaddune/Universal7885-P](https://github.com/prashantpaddune/Universal7885-P)
- **Vendor:** Quack V2.6
- **GSI:** treble_arm64_bvS (Android 11)
- **Docker:** Docker CE 27.3.1 aarch64 oficial

---

**Documentação completa:** `docs/BUILD_LOG.md` — diário de bordo desde o primeiro boot loop até o container funcionando.
