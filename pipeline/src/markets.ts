import { zurichDate } from "./calendar.ts";
import { MARKET_NAMES, type Quote } from "./schema.ts";

// Closing figures come from Yahoo Finance's public chart endpoint (no key). Exact numbers
// are where a language model is weakest, so the job fetches them and hands them to
// Claude. If a symbol fails, Claude looks it up instead.

interface Instrument {
  name: (typeof MARKET_NAMES)[number];
  symbol: string;
  unit: Quote["unit"];
}

const INSTRUMENTS: Instrument[] = [
  { name: "S&P 500", symbol: "^GSPC", unit: "index" },
  { name: "Nasdaq", symbol: "^IXIC", unit: "index" },
  { name: "SMI", symbol: "^SSMI", unit: "index" },
  { name: "US 10Y", symbol: "^TNX", unit: "yield" },
  { name: "USD/CHF", symbol: "CHF=X", unit: "fx" },
  { name: "Brent", symbol: "BZ=F", unit: "usd" },
];

export interface MarketSnapshot {
  /** Date of the last US close, YYYY-MM-DD */
  asOf: string | null;
  quotes: Quote[];
  missing: Instrument["name"][];
}

interface Bar {
  date: string;
  close: number;
}

async function fetchBars(symbol: string): Promise<Bar[]> {
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?range=1mo&interval=1d`;
  const response = await fetch(url, {
    headers: { "User-Agent": "Mozilla/5.0 (Court & Capital morning edition)" },
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) throw new Error(`${symbol}: HTTP ${response.status}`);
  const body = (await response.json()) as {
    chart?: { result?: { timestamp?: number[]; indicators?: { quote?: { close?: (number | null)[] }[] } }[] };
  };
  const result = body.chart?.result?.[0];
  const timestamps = result?.timestamp ?? [];
  const closes = result?.indicators?.quote?.[0]?.close ?? [];
  const bars: Bar[] = [];
  timestamps.forEach((timestamp, index) => {
    const close = closes[index];
    if (typeof close === "number" && Number.isFinite(close)) {
      bars.push({ date: zurichDate(new Date(timestamp * 1000)), close });
    }
  });
  return bars;
}

function round(value: number, places: number): number {
  const factor = 10 ** places;
  return Math.round(value * factor) / factor;
}

/**
 * The last completed close before the edition date and its change on the day: percent for
 * indices, FX and Brent, basis points for the 10-year yield.
 */
export async function fetchMarkets(editionDate: string): Promise<MarketSnapshot> {
  const quotes: Quote[] = [];
  const missing: Instrument["name"][] = [];
  let asOf: string | null = null;

  for (const instrument of INSTRUMENTS) {
    try {
      const bars = (await fetchBars(instrument.symbol)).filter((bar) => bar.date < editionDate);
      const last = bars.at(-1);
      const previous = bars.at(-2);
      if (!last || !previous) throw new Error(`${instrument.symbol}: not enough closes`);
      const isYield = instrument.unit === "yield";
      quotes.push({
        name: instrument.name,
        level: round(last.close, isYield ? 3 : instrument.unit === "fx" ? 4 : 2),
        change: isYield ? round((last.close - previous.close) * 100, 1) : round((last.close / previous.close - 1) * 100, 2),
        change_unit: isYield ? "bp" : "percent",
        unit: instrument.unit,
      });
      if (instrument.name === "S&P 500") asOf = last.date;
    } catch (error) {
      console.warn(`Market data: ${instrument.name} unavailable (${(error as Error).message})`);
      missing.push(instrument.name);
    }
  }
  return { asOf, quotes, missing };
}

export function formatQuote(quote: Quote): string {
  const level =
    quote.unit === "yield"
      ? `${quote.level.toFixed(2)}%`
      : quote.unit === "usd"
        ? `$${quote.level.toFixed(2)}`
        : quote.unit === "fx"
          ? quote.level.toFixed(4)
          : quote.level.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const sign = quote.change > 0 ? "+" : quote.change < 0 ? "−" : "±";
  const change =
    quote.change_unit === "bp" ? `${sign}${Math.abs(quote.change).toFixed(1)} bp` : `${sign}${Math.abs(quote.change).toFixed(2)}%`;
  return `${quote.name}: ${level} (${change})`;
}

export function orderQuotes(quotes: Quote[]): Quote[] {
  return [...quotes].sort((a, b) => MARKET_NAMES.indexOf(a.name) - MARKET_NAMES.indexOf(b.name));
}

export const UNITS: Record<(typeof MARKET_NAMES)[number], Quote["unit"]> = Object.fromEntries(
  INSTRUMENTS.map((instrument) => [instrument.name, instrument.unit]),
) as Record<(typeof MARKET_NAMES)[number], Quote["unit"]>;
