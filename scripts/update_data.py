#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import re
import statistics
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import parse_qs, quote, unquote, urlparse

import requests
from bs4 import BeautifulSoup

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/122.0.0.0 Safari/537.36"
    )
}
TIMEOUT_SECONDS = 20
JST = timezone(timedelta(hours=9))

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_TARGETS = [ROOT / "data", ROOT / "assets" / "data", ROOT / "web" / "data"]

MANUFACTURER_QUERIES = [
    {
        "manufacturer": "BANDAI",
        "sourceLabel": "BANDAI ガシャポン",
        "domain": "gashapon.jp",
        "query": "site:gashapon.jp ガシャポン 新商品",
    },
    {
        "manufacturer": "タカラトミーアーツ",
        "sourceLabel": "タカラトミーアーツ",
        "domain": "takaratomy-arts.co.jp",
        "query": "site:takaratomy-arts.co.jp ガチャ 新商品",
    },
    {
        "manufacturer": "ケンエレファント",
        "sourceLabel": "ケンエレファント",
        "domain": "kenelephant.co.jp",
        "query": "site:kenelephant.co.jp カプセルトイ 新作",
    },
    {
        "manufacturer": "スタンド・ストーンズ",
        "sourceLabel": "スタンド・ストーンズ",
        "domain": "stasto.co.jp",
        "query": "site:stasto.co.jp カプセルトイ 新商品",
    },
    {
        "manufacturer": "エール",
        "sourceLabel": "エール",
        "domain": "yell-world.jp",
        "query": "site:yell-world.jp ガチャ 新商品",
    },
]

X_KEYWORDS = [
    "ガシャポン 新商品",
    "ガチャ 新作",
    "カプセルトイ 新商品",
    "たまごっち ガチャ",
    "サンリオ ガチャ 新作",
]

MARKETPLACE_SPECS = [
    {
        "name": "メルカリ",
        "domain": "jp.mercari.com",
    },
    {
        "name": "Yahoo!フリマ",
        "domain": "paypayfleamarket.yahoo.co.jp",
    },
]

DATE_WITH_YEAR = re.compile(
    r"(20\d{2})\s*[./\-年]\s*(\d{1,2})\s*[./\-月]\s*(\d{1,2})\s*(?:日)?"
)
DATE_NO_YEAR = re.compile(r"(\d{1,2})\s*[./\-月]\s*(\d{1,2})\s*(?:日)?")
PRICE_PATTERN = re.compile(r"(?:¥|￥)?\s*([0-9][0-9,]{2,})\s*円?")
NON_PRODUCT_PATH_PREFIXES = [
    "/about",
    "/contact",
    "/recruit",
    "/search",
    "/feed",
    "/newsed",
    "/books",
    "/vinyl",
    "/wp-",
]

URL_CHECK_CACHE: dict[str, bool] = {}


class FetchError(RuntimeError):
    pass


def clean_text(value: str | None) -> str:
    if not value:
        return ""
    return re.sub(r"\s+", " ", value).strip()


def build_id(prefix: str, value: str) -> str:
    hash_id = hashlib.md5(value.encode("utf-8")).hexdigest()[:12]
    return f"{prefix}_{hash_id}"


def fetch_html(url: str) -> str:
    try:
        response = requests.get(url, headers=HEADERS, timeout=TIMEOUT_SECONDS)
        response.raise_for_status()
        return response.text
    except Exception as exc:
        raise FetchError(str(exc)) from exc


def looks_like_product_url(url: str) -> bool:
    try:
        parsed = urlparse(url)
    except Exception:
        return False

    if not parsed.scheme.startswith("http"):
        return False

    path = parsed.path or "/"
    normalized_path = path.rstrip("/") or "/"
    query = parsed.query or ""

    for prefix in NON_PRODUCT_PATH_PREFIXES:
        if normalized_path.startswith(prefix.rstrip("/")):
            return False

    if normalized_path == "/":
        # Some sites use query id-style product pages, e.g. ?p=12345
        if re.search(r"(?:^|&)(?:p|item|product|id)=", query):
            return True
        return False

    return True


def is_live_url(url: str) -> bool:
    cached = URL_CHECK_CACHE.get(url)
    if cached is not None:
        return cached

    ok = False
    try:
        response = requests.get(
            url,
            headers=HEADERS,
            timeout=TIMEOUT_SECONDS,
            allow_redirects=True,
            stream=True,
        )
        ok = 200 <= response.status_code < 400
        response.close()
    except Exception:
        ok = False

    URL_CHECK_CACHE[url] = ok
    return ok


def normalize_ddg_url(url: str) -> str:
    try:
        parsed = urlparse(url)
    except Exception:
        return url

    if parsed.netloc.endswith("duckduckgo.com") and parsed.path == "/l/":
        params = parse_qs(parsed.query)
        if "uddg" in params and params["uddg"]:
            return unquote(params["uddg"][0])

    return url


def search_duckduckgo(query: str, max_results: int = 10) -> list[dict]:
    url = "https://duckduckgo.com/html/?q=" + quote(query)
    html = fetch_html(url)
    soup = BeautifulSoup(html, "html.parser")

    results = []
    for node in soup.select("div.result"):
        link = node.select_one("a.result__a")
        if not link:
            continue

        href = link.get("href")
        if not href:
            continue

        normalized_url = normalize_ddg_url(href)
        if not normalized_url.startswith("http"):
            continue

        title = clean_text(link.get_text())
        snippet_node = node.select_one(".result__snippet")
        snippet = clean_text(snippet_node.get_text()) if snippet_node else ""

        results.append({
            "title": title,
            "url": normalized_url,
            "snippet": snippet,
        })

        if len(results) >= max_results:
            break

    return results


def parse_relative_time(text: str) -> timedelta | None:
    match = re.search(r"(\d+)\s*(分|時間|日)前", text)
    if not match:
        return None

    value = int(match.group(1))
    unit = match.group(2)
    if unit == "分":
        return timedelta(minutes=value)
    if unit == "時間":
        return timedelta(hours=value)
    if unit == "日":
        return timedelta(days=value)
    return None


def extract_date_candidates(text: str, now: datetime) -> list[datetime]:
    candidates = []
    year_spans = []

    for match in DATE_WITH_YEAR.finditer(text):
        year, month, day = map(int, match.groups())
        try:
            candidates.append(datetime(year, month, day, tzinfo=now.tzinfo))
            year_spans.append((match.start(), match.end()))
        except ValueError:
            continue

    for match in DATE_NO_YEAR.finditer(text):
        if any(start <= match.start() < end for start, end in year_spans):
            continue

        month, day = map(int, match.groups())
        try:
            candidate = datetime(now.year, month, day, tzinfo=now.tzinfo)
        except ValueError:
            continue

        if candidate < now - timedelta(days=180):
            candidate = datetime(now.year + 1, month, day, tzinfo=now.tzinfo)

        candidates.append(candidate)

    return candidates


def select_release_date(candidates: list[datetime], now: datetime) -> datetime | None:
    if not candidates:
        return None

    near_window = [date for date in candidates if now - timedelta(days=60) <= date <= now + timedelta(days=240)]
    if near_window:
        near_window.sort(key=lambda item: abs((item - now).days))
        return near_window[0]

    candidates.sort()
    return candidates[-1]


def extract_price_candidates(text: str, min_price: int, max_price: int) -> list[int]:
    values = []
    for match in PRICE_PATTERN.finditer(text):
        digits = match.group(1).replace(",", "")
        try:
            price = int(digits)
        except ValueError:
            continue
        if min_price <= price <= max_price:
            values.append(price)
    return values


def extract_price_yen(text: str) -> int | None:
    candidates = extract_price_candidates(text, min_price=100, max_price=3000)
    if not candidates:
        return None
    return candidates[0]


def infer_series(text: str) -> str | None:
    candidates = [
        "サンリオ",
        "ちいかわ",
        "たまごっち",
        "ポケモン",
        "ディズニー",
        "ドラえもん",
        "おぱんちゅうさぎ",
        "ワンピース",
    ]

    for word in candidates:
        if word in text:
            return word
    return None


def build_release_entry(item: dict, spec: dict, now: datetime) -> dict:
    combined = clean_text(f"{item['title']} {item['snippet']}")
    candidates = extract_date_candidates(combined, now)
    release_date = select_release_date(candidates, now)
    price = extract_price_yen(combined)

    return {
        "id": build_id("rel", item["url"]),
        "title": item["title"],
        "manufacturer": spec["manufacturer"],
        "series": infer_series(combined),
        "releaseDate": release_date.strftime("%Y-%m-%d") if release_date else None,
        "priceYen": price,
        "sourceLabel": spec["sourceLabel"],
        "sourceUrl": item["url"],
        "imageUrl": None,
        "summary": item["snippet"] or item["title"],
        "tags": ["新作", "メーカー情報"],
        "marketPrices": [],
    }


def build_market_search_url(marketplace_name: str, product_name: str) -> str:
    encoded = quote(product_name)
    if marketplace_name == "メルカリ":
        return f"https://jp.mercari.com/search?keyword={encoded}"
    if marketplace_name == "Yahoo!フリマ":
        return f"https://paypayfleamarket.yahoo.co.jp/search/{encoded}"
    return f"https://duckduckgo.com/?q={encoded}"


def collect_market_prices_for_keyword(product_name: str, now: datetime) -> list[dict]:
    outputs = []
    for spec in MARKETPLACE_SPECS:
        query = f"site:{spec['domain']} {product_name}"
        try:
            results = search_duckduckgo(query, max_results=10)
        except FetchError:
            continue

        prices = []
        for item in results:
            if spec["domain"] not in item["url"]:
                continue
            combined = clean_text(f"{item['title']} {item['snippet']}")
            prices.extend(
                extract_price_candidates(
                    combined,
                    min_price=100,
                    max_price=50000,
                )
            )

        if not prices:
            continue

        prices.sort()
        median_price = int(statistics.median(prices))
        outputs.append(
            {
                "marketplace": spec["name"],
                "searchUrl": build_market_search_url(spec["name"], product_name),
                "sampleCount": len(prices),
                "minPriceYen": prices[0],
                "medianPriceYen": median_price,
                "maxPriceYen": prices[-1],
                "updatedAt": now.isoformat(),
            }
        )
        time.sleep(0.35)

    return outputs


def enrich_release_market_prices(releases: list[dict], now: datetime):
    cache = {}
    for release in releases:
        product_name = clean_text(release.get("title") or "")
        if not product_name:
            release["marketPrices"] = []
            continue

        if product_name in cache:
            market_prices = cache[product_name]
        else:
            market_prices = collect_market_prices_for_keyword(product_name, now)
            cache[product_name] = market_prices

        release["marketPrices"] = market_prices
        if market_prices and "中古相場" not in release["tags"]:
            release["tags"].append("中古相場")


def collect_releases() -> list[dict]:
    now = datetime.now(JST)
    releases = []
    seen_urls = set()

    for spec in MANUFACTURER_QUERIES:
        try:
            results = search_duckduckgo(spec["query"], max_results=12)
        except FetchError:
            continue

        for item in results:
            url = item["url"]
            if spec["domain"] not in url:
                continue
            if not looks_like_product_url(url):
                continue
            if not is_live_url(url):
                continue
            if url in seen_urls:
                continue
            seen_urls.add(url)

            entry = build_release_entry(item, spec, now)
            releases.append(entry)

        time.sleep(0.5)

    enrich_release_market_prices(releases, now)

    releases.sort(
        key=lambda item: (item["releaseDate"] is None, item["releaseDate"] or "", item["title"]),
        reverse=True,
    )
    return releases[:200]


def search_yahoo_realtime(keyword: str, max_urls: int = 40) -> list[dict]:
    url = "https://search.yahoo.co.jp/realtime/search?p=" + quote(keyword) + "&ei=UTF-8"
    html = fetch_html(url)

    seen_urls = set()
    posts = []
    now = datetime.now(timezone.utc)

    for match in re.finditer(r"https://(?:twitter\.com|x\.com)/[^/]+/status/\d+", html):
        x_url = match.group(0)
        if x_url in seen_urls:
            continue
        seen_urls.add(x_url)

        window = html[max(0, match.start() - 220): match.end() + 220]
        delta = parse_relative_time(window)
        posted_at = now - delta if delta else now

        username_match = re.search(r"/(?:twitter\.com|x\.com)/([^/]+)/status/", x_url)
        username = f"@{username_match.group(1)}" if username_match else "@unknown"
        status_match = re.search(r"/status/(\d+)", x_url)
        status_id = status_match.group(1) if status_match else build_id("x", x_url)

        posts.append(
            {
                "id": f"x_{status_id}",
                "platform": "X",
                "username": username,
                "content": f"{keyword} に関する投稿",
                "url": x_url,
                "postedAt": posted_at.isoformat(),
                "matchedKeyword": keyword,
            }
        )

        if len(posts) >= max_urls:
            break

    return posts


def strip_html(text: str) -> str:
    return BeautifulSoup(text, "html.parser").get_text(" ", strip=True)


def fetch_x_oembed_text(url: str) -> str | None:
    try:
        endpoint = "https://publish.twitter.com/oembed?omit_script=1&url=" + quote(url, safe="")
        response = requests.get(endpoint, headers=HEADERS, timeout=TIMEOUT_SECONDS)
        if response.status_code != 200:
            return None
        payload = response.json()
        html = payload.get("html", "")
        text = strip_html(html)
        return clean_text(text) or None
    except Exception:
        return None


def enrich_x_posts(posts: list[dict], limit: int = 20):
    for index, post in enumerate(posts):
        if index >= limit:
            break

        enriched = fetch_x_oembed_text(post["url"])
        if enriched:
            post["content"] = enriched

        time.sleep(0.35)


def collect_x_posts() -> list[dict]:
    posts = []
    seen_urls = set()

    for keyword in X_KEYWORDS:
        try:
            items = search_yahoo_realtime(keyword)
        except FetchError:
            items = []

        for item in items:
            url = item["url"]
            if url in seen_urls:
                continue
            seen_urls.add(url)
            posts.append(item)

        time.sleep(0.5)

    posts.sort(key=lambda item: item["postedAt"], reverse=True)
    enrich_x_posts(posts, limit=25)
    return posts[:300]


def write_json(path: Path, payload: list[dict]):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)


def read_json(path: Path) -> list[dict]:
    if not path.exists():
        return []
    try:
        with path.open("r", encoding="utf-8") as handle:
            payload = json.load(handle)
    except Exception:
        return []
    return payload if isinstance(payload, list) else []


def seed_releases() -> list[dict]:
    return [
        {
            "id": "rel_seed_bandai",
            "title": "サンリオキャラクターズ カプセルラバーマスコット",
            "manufacturer": "BANDAI",
            "series": "サンリオ",
            "releaseDate": "2026-03-15",
            "priceYen": 400,
            "sourceLabel": "BANDAI ガシャポン",
            "sourceUrl": "https://gashapon.jp/products/",
            "imageUrl": None,
            "summary": "初期データ: 取得失敗時に表示するサンプルです。",
            "tags": ["新作", "サンプル", "中古相場"],
            "marketPrices": [
                {
                    "marketplace": "メルカリ",
                    "searchUrl": "https://jp.mercari.com/search?keyword=%E3%82%B5%E3%83%B3%E3%83%AA%E3%82%AA%E3%82%AD%E3%83%A3%E3%83%A9%E3%82%AF%E3%82%BF%E3%83%BC%E3%82%BA%20%E3%82%AB%E3%83%97%E3%82%BB%E3%83%AB%E3%83%A9%E3%83%90%E3%83%BC%E3%83%9E%E3%82%B9%E3%82%B3%E3%83%83%E3%83%88",
                    "sampleCount": 12,
                    "minPriceYen": 300,
                    "medianPriceYen": 680,
                    "maxPriceYen": 1800,
                    "updatedAt": "2026-02-27T12:00:00+09:00",
                }
            ],
        }
    ]


def seed_posts() -> list[dict]:
    return [
        {
            "id": "x_seed_1",
            "platform": "X",
            "username": "@gacha_news",
            "content": "初期データ: 取得失敗時に表示するサンプル投稿です。",
            "url": "https://x.com/gacha_news/status/1900000000000000001",
            "postedAt": "2026-02-27T10:20:00Z",
            "matchedKeyword": "ガシャポン 新商品",
        }
    ]


def save_payload(name: str, payload: list[dict]):
    for directory in OUTPUT_TARGETS:
        write_json(directory / name, payload)


def main() -> int:
    previous_releases = read_json(ROOT / "data" / "releases.json")
    previous_posts = read_json(ROOT / "data" / "x_posts.json")

    releases = collect_releases()
    posts = collect_x_posts()

    if not releases:
        releases = previous_releases or seed_releases()
    if not posts:
        posts = previous_posts or seed_posts()

    save_payload("releases.json", releases)
    save_payload("x_posts.json", posts)

    print(f"saved releases: {len(releases)}")
    print(f"saved x posts: {len(posts)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
