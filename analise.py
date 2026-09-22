import csv
from collections import defaultdict

# Lê a base de teste e agrupa os tipos de manutenção por equipamento
tipos_por_equipamento = defaultdict(list)

with open("ordens_teste.csv", encoding="utf-8") as arquivo:
    for linha in csv.DictReader(arquivo):
        tipos_por_equipamento[linha["equipamento"]].append(linha["tipo"])

print("Equipamentos com preventiva que mesmo assim quebraram:\n")

for equipamento, tipos in tipos_por_equipamento.items():
    preventivas = tipos.count("Preventiva")
    corretivas = tipos.count("Corretiva")
    if preventivas > 0 and corretivas > 0:
        print(f"- {equipamento}: {preventivas} preventiva(s), {corretivas} corretiva(s)")
