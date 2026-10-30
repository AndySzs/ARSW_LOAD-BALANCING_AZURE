"""Genera las gráficas del informe a partir de los archivos de results/."""
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "images", "solution")
os.makedirs(OUT, exist_ok=True)

A, B, C = "#2a78d6", "#e8743b", "#1a9e75"
plt.rcParams.update({"font.size": 10, "axes.spines.top": False, "axes.spines.right": False})


def load_times(name):
    rows = [l.split() for l in open(os.path.join(HERE, name)) if l.strip() and not l.startswith("#")]
    return [int(r[0]) for r in rows], [float(r[2]) for r in rows]


def load_cpu(name):
    rows = [l.split() for l in open(os.path.join(HERE, name)) if l.strip() and not l.startswith("#")]
    return [r[0] for r in rows], [float(r[1]) for r in rows], [float(r[2]) for r in rows]


# 1. Tiempos de respuesta
n, t2 = load_times("times_D2s_v4.txt")
_, t4 = load_times("times_D4s_v4.txt")
fig, ax = plt.subplots(figsize=(7, 3.6))
ax.plot([x / 1e6 for x in n], t2, "o-", color=A, label="D2s_v4 (2 vCPU)")
ax.plot([x / 1e6 for x in n], t4, "s-", color=B, label="D4s_v4 (4 vCPU)")
ax.set_xlabel("n (millones)")
ax.set_ylabel("Tiempo de respuesta (s)")
ax.set_title("Tiempo de respuesta de /fibonacci/n")
ax.set_ylim(0, 14)
ax.grid(axis="y", alpha=.3)
ax.legend(frameon=False)
fig.tight_layout()
fig.savefig(os.path.join(OUT, "chart-tiempos-p1.png"), dpi=150)

# 2. CPU por VM
for f, title, vcpu in [("cpu_D2s_v4.tsv", "VERTICAL-SCALABILITY · D2s_v4", 2),
                       ("cpu_D4s_v4.tsv", "VERTICAL-SCALABILITY · D4s_v4", 4)]:
    if not os.path.exists(os.path.join(HERE, f)):
        continue
    ts, avg, mx = load_cpu(f)
    fig, ax = plt.subplots(figsize=(7, 3.2))
    ax.plot(ts, mx, "o-", color=B, label="Máximo")
    ax.plot(ts, avg, "o-", color=A, label="Promedio")
    ax.axhline(100 / vcpu, ls="--", color="#888", lw=1)
    ax.text(len(ts) - 1, 100 / vcpu + 2, "1 núcleo al 100%", ha="right", color="#666", fontsize=8)
    ax.axhline(70, ls=":", color="#c0392b", lw=1)
    ax.text(0, 72, "Límite escenario de calidad (70%)", color="#c0392b", fontsize=8)
    ax.set_ylim(0, 100)
    ax.set_ylabel("Percentage CPU (%)")
    ax.set_xlabel("Hora (UTC)")
    ax.set_title(f"Uso de CPU · {title}")
    ax.tick_params(axis="x", rotation=45)
    ax.grid(axis="y", alpha=.3)
    ax.legend(frameon=False, loc="upper right")
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, "chart-" + f.replace(".tsv", ".png")), dpi=150)

# 3. CPU parte 2 (varias VMs)
p2 = [f for f in sorted(os.listdir(HERE)) if f.startswith("cpu_p2_") and f.endswith(".tsv")]
for f in p2:
    vms = {}
    for l in open(os.path.join(HERE, f)):
        if not l.strip() or l.startswith("#"):
            continue
        vm, ts, avg, mx = l.split()
        vms.setdefault(vm, []).append((ts, float(avg), float(mx)))
    fig, ax = plt.subplots(figsize=(7, 3.4))
    colors = [A, B, C, "#8e44ad"]
    for (vm, rows), c in zip(sorted(vms.items()), colors):
        ax.plot([r[0] for r in rows], [r[2] for r in rows], "o-", color=c, label=vm + " (máx)")
    ax.axhline(70, ls=":", color="#c0392b", lw=1)
    ax.set_ylim(0, 100)
    ax.set_ylabel("Percentage CPU (%)")
    ax.set_xlabel("Hora (UTC)")
    ax.set_title("Uso de CPU por nodo detrás del balanceador")
    ax.tick_params(axis="x", rotation=45)
    ax.grid(axis="y", alpha=.3)
    ax.legend(frameon=False, ncol=2, fontsize=8)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, "chart-" + f.replace(".tsv", ".png")), dpi=150)

print("ok")
