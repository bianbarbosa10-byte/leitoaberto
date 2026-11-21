import * as echarts from "echarts/core";
import { LineChart, BarChart, HeatmapChart, MapChart } from "echarts/charts";
import {
  GridComponent, TooltipComponent, LegendComponent, MarkLineComponent, MarkAreaComponent,
  VisualMapComponent, GeoComponent,
} from "echarts/components";
import { SVGRenderer } from "echarts/renderers";

echarts.use([LineChart, BarChart, HeatmapChart, MapChart, GridComponent, TooltipComponent, LegendComponent,
  MarkLineComponent, MarkAreaComponent, VisualMapComponent, GeoComponent, SVGRenderer]);

type Unit = "pct" | "int" | "dec1" | "dec2";
interface Serie { name: string; data: (number | null)[]; slot?: number }
interface Spec {
  kind: "line" | "bar" | "heatmap" | "map";
  unit: Unit;
  x?: string[];
  y?: string[];
  series?: Serie[];
  data?: [number, number, number][];
  values?: { cod: string; nome: string; value: number | null }[];
  horizontal?: boolean;
  stack?: boolean;
  ref?: { value: number; label: string };
  preliminarDesde?: number; // indice do eixo x a partir do qual os dados sao preliminares
  min0?: boolean;
}

const css = (v: string) => getComputedStyle(document.documentElement).getPropertyValue(v).trim();
const nf = (d: number) => new Intl.NumberFormat("pt-BR", { minimumFractionDigits: d, maximumFractionDigits: d });
const fmt = (u: Unit, v: number | null | undefined) => {
  if (v == null || Number.isNaN(v)) return "–";
  if (u === "pct") return nf(1).format(v * 100) + "%";
  if (u === "dec1") return nf(1).format(v);
  if (u === "dec2") return nf(2).format(v);
  return nf(0).format(v);
};
const fmtEixo = (u: Unit) => (v: number) => (u === "pct" ? nf(0).format(v * 100) + "%" : nf(u === "int" ? 0 : 1).format(v));

let geoPronto: Promise<void> | null = null;
function carregarMapa() {
  if (!geoPronto) {
    const base = document.body.dataset.base || "";
    geoPronto = fetch(`${base}/data/es_municipios.geojson`).then((r) => r.json()).then((g) => {
      for (const f of g.features) f.properties.name = String(f.properties.codarea).slice(0, 6);
      echarts.registerMap("ES", g);
    });
  }
  return geoPronto;
}

function opcoes(s: Spec): echarts.EChartsCoreOption {
  const ink = css("--text-primary"), ink2 = css("--text-secondary"), muted = css("--text-muted");
  const grid = css("--grid"), axis = css("--axis"), surface = css("--surface-1");
  const cores = [css("--series-1"), css("--series-2"), css("--series-3"), css("--series-4")];
  const tooltip = {
    backgroundColor: surface, borderColor: axis, textStyle: { color: ink, fontSize: 13 },
    extraCssText: "border-radius:8px;box-shadow:0 4px 14px rgba(0,0,0,.12);",
  };
  const texto = { color: ink2, fontFamily: "system-ui, -apple-system, Segoe UI, sans-serif" };

  if (s.kind === "map") {
    const vals = s.values!.map((d) => d.value).filter((v): v is number => v != null);
    return {
      textStyle: texto,
      tooltip: {
        ...tooltip, trigger: "item",
        formatter: (p: any) => `<b>${p.data?.nome ?? p.name}</b><br>${fmt(s.unit, p.data?.value)}`,
      },
      visualMap: {
        min: Math.min(...vals), max: Math.max(...vals), orient: "horizontal", left: "center", bottom: 0,
        itemWidth: 12, itemHeight: 160, calculable: false, text: [fmt(s.unit, Math.max(...vals)), fmt(s.unit, Math.min(...vals))],
        textStyle: { color: ink2 }, inRange: { color: [css("--seq-100"), "#5598e7", css("--seq-700")] },
      },
      series: [{
        type: "map", map: "ES", roam: false, top: 10, bottom: 50,
        itemStyle: { borderColor: surface, borderWidth: 0.8, areaColor: css("--surface-2") },
        emphasis: { label: { show: false }, itemStyle: { areaColor: css("--series-4") } },
        select: { disabled: true },
        data: s.values!.map((d) => ({ name: d.cod, nome: d.nome, value: d.value })),
      }],
    };
  }

  if (s.kind === "heatmap") {
    const vs = s.data!.map((d) => d[2]);
    return {
      textStyle: texto,
      tooltip: { ...tooltip, formatter: (p: any) => `${s.y![p.value[1]]} → ${s.x![p.value[0]]}<br><b>${fmt(s.unit, p.value[2])}</b>` },
      grid: { left: 110, right: 16, top: 30, bottom: 60 },
      xAxis: { type: "category", data: s.x, position: "top", axisLine: { show: false }, axisTick: { show: false }, axisLabel: { color: ink2 } },
      yAxis: { type: "category", data: s.y, inverse: true, axisLine: { show: false }, axisTick: { show: false }, axisLabel: { color: ink2 } },
      visualMap: { min: 0, max: Math.max(...vs), show: false, inRange: { color: [css("--seq-100"), css("--seq-700")] } },
      series: [{
        type: "heatmap", itemStyle: { borderColor: surface, borderWidth: 2, borderRadius: 4 },
        // texto claro sobre celula escura, escuro sobre celula clara
        data: s.data!.map((d) => ({ value: d, label: { color: d[2] > 0.45 * Math.max(...vs) ? "#ffffff" : ink } })),
        label: { show: true, fontSize: 12, formatter: (p: any) => fmt(s.unit, p.value[2]) },
      }],
    };
  }

  const multi = (s.series?.length ?? 0) > 1;
  const valAxis = {
    type: "value", min: s.min0 === false ? "dataMin" : 0,
    axisLabel: { color: muted, formatter: fmtEixo(s.unit) },
    splitLine: { lineStyle: { color: grid } }, axisLine: { show: false },
  };
  const catAxis = {
    type: "category", data: s.x, axisLine: { lineStyle: { color: axis } }, axisTick: { show: false },
    axisLabel: { color: muted, hideOverlap: true },
  };
  const series = s.series!.map((se, i) => {
    const cor = cores[(se.slot ?? i) % cores.length];
    const comum: any = { name: se.name, data: se.data, color: cor, emphasis: { focus: "series" } };
    if (s.kind === "line") {
      Object.assign(comum, { type: "line", symbol: "circle", symbolSize: 8, showSymbol: false, lineStyle: { width: 2 },
        endLabel: multi && s.series!.length <= 4 ? { show: true, formatter: "{a}", color: ink2, fontSize: 12 } : undefined });
    } else {
      Object.assign(comum, { type: "bar", barMaxWidth: 28, stack: s.stack ? "t" : undefined,
        itemStyle: { borderRadius: s.horizontal ? [0, 4, 4, 0] : [4, 4, 0, 0], borderColor: surface, borderWidth: s.stack ? 1 : 0 } });
    }
    return comum;
  });
  if (s.ref && series[0]) {
    series[0].markLine = {
      symbol: "none", silent: true, lineStyle: { color: ink2, type: "dashed", width: 1 },
      // no grafico horizontal o rotulo colidiria com o eixo: o subtitulo do card explica a linha
      label: { show: !s.horizontal, formatter: s.ref.label, color: ink2, position: "insideEndTop" },
      data: [s.horizontal ? { xAxis: s.ref.value } : { yAxis: s.ref.value }],
    };
  }
  if (s.preliminarDesde != null && s.x && s.preliminarDesde < s.x.length && series[0]) {
    series[0].markArea = {
      silent: true, itemStyle: { color: css("--surface-2") },
      label: { show: true, position: "insideTop", color: muted, fontSize: 11, formatter: "preliminar" },
      data: [[{ xAxis: s.x[s.preliminarDesde] }, { xAxis: s.x[s.x.length - 1] }]],
    };
  }
  return {
    textStyle: texto,
    legend: multi ? { top: 0, left: 0, icon: "roundRect", itemWidth: 12, itemHeight: 12, textStyle: { color: ink2 } } : undefined,
    tooltip: {
      ...tooltip, trigger: "axis", axisPointer: { type: s.kind === "line" ? "line" : "shadow", lineStyle: { color: axis } },
      valueFormatter: (v: number) => fmt(s.unit, v),
    },
    grid: { left: s.horizontal ? 8 : 8, right: s.kind === "line" && multi ? 110 : 24, top: multi ? 40 : 16, bottom: 8, containLabel: true },
    xAxis: s.horizontal ? valAxis : catAxis,
    yAxis: s.horizontal ? { ...catAxis, inverse: true, axisLabel: { color: ink2, width: 190, overflow: "truncate" } } : valAxis,
    series,
  };
}

const graficos: { el: HTMLElement; chart: echarts.ECharts; spec: () => Spec }[] = [];

function specAtual(el: HTMLElement): Spec {
  const anos = el.dataset.chartYears;
  if (anos) {
    const porAno = JSON.parse(anos) as Record<string, Spec>;
    const ano = (document.querySelector<HTMLSelectElement>("[data-year-filter]")?.value) || Object.keys(porAno).pop()!;
    return porAno[ano] ?? Object.values(porAno).pop()!;
  }
  return JSON.parse(el.dataset.chart!);
}

async function iniciarGraficos() {
  const els = document.querySelectorAll<HTMLElement>("[data-chart],[data-chart-years]");
  for (const el of els) {
    const spec = () => specAtual(el);
    if (spec().kind === "map") await carregarMapa();
    const chart = echarts.init(el, undefined, { renderer: "svg" });
    chart.setOption(opcoes(spec()));
    graficos.push({ el, chart, spec });
  }
  new ResizeObserver(() => graficos.forEach((g) => g.chart.resize())).observe(document.body);
}

function redesenhar() {
  graficos.forEach((g) => g.chart.setOption(opcoes(g.spec()), true));
}

// ---------- filtro de ano: mostra blocos [data-year] e troca os graficos
function iniciarFiltro() {
  const sel = document.querySelector<HTMLSelectElement>("[data-year-filter]");
  if (!sel) return;
  const aplicar = () => {
    document.querySelectorAll<HTMLElement>("[data-year]").forEach((el) => el.classList.toggle("ativo", el.dataset.year === sel.value));
    redesenhar();
  };
  sel.addEventListener("change", aplicar);
  document.querySelectorAll<HTMLElement>("[data-year]").forEach((el) => el.classList.toggle("ativo", el.dataset.year === sel.value));
}

// ---------- ordenacao de tabelas (clique no cabecalho)
function iniciarTabelas() {
  document.querySelectorAll<HTMLTableElement>("table[data-sortable]").forEach((t) => {
    t.querySelectorAll<HTMLTableCellElement>("th").forEach((th, i) => {
      th.dataset.sort = "";
      let asc = false;
      th.addEventListener("click", () => {
        const tb = t.tBodies[0];
        const linhas = [...tb.rows];
        linhas.sort((a, b) => {
          const va = a.cells[i].dataset.v ?? a.cells[i].textContent ?? "";
          const vb = b.cells[i].dataset.v ?? b.cells[i].textContent ?? "";
          const na = parseFloat(va), nb = parseFloat(vb);
          const r = !isNaN(na) && !isNaN(nb) ? na - nb : va.localeCompare(vb, "pt-BR");
          return asc ? r : -r;
        });
        asc = !asc;
        linhas.forEach((l) => tb.appendChild(l));
      });
    });
  });
}

// ---------- tema
function iniciarTema() {
  document.getElementById("tema")?.addEventListener("click", () => {
    const escuro = document.documentElement.dataset.theme
      ? document.documentElement.dataset.theme === "dark"
      : matchMedia("(prefers-color-scheme: dark)").matches;
    const novo = escuro ? "light" : "dark";
    document.documentElement.dataset.theme = novo;
    try { localStorage.setItem("tema", novo); } catch (e) { /* armazenamento indisponivel */ }
    redesenhar();
  });
  matchMedia("(prefers-color-scheme: dark)").addEventListener("change", redesenhar);
}

iniciarTema();
iniciarFiltro();
iniciarTabelas();
iniciarGraficos();
