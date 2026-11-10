// GitMorning site: Korean text, copy buttons, and today's list from the public feed.
// No cookies, storage of personal data, or third-party requests.
(() => {
  const ko = {
    "nav.today": "오늘",
    "nav.features": "기능",
    "nav.install": "설치",
    "hero.badge": "새 소식",
    "hero.title": "매일 아침, Mac에서<br>GitHub 트렌드를.",
    "hero.lead": "GitMorning은 어제보다 새로 올라오거나 순위가 오른 프로젝트만 골라 보여주고, 설명을 내 언어로 읽게 해 주며, 써 보고 싶은 도구를 보관해 둡니다. 메뉴 막대에서, 계정 없이.",
    "hero.download": "ZIP 다운로드",
    "hero.fine": "무료 · MIT · Apple Silicon · macOS 14 이상",
    "copy": "복사",
    "copied": "복사됨",
    "today.eyebrow": "피드에서 실시간으로",
    "today.title": "오늘의 GitHub 트렌드",
    "today.lead": "앱이 읽는 것과 같은 공개 목록입니다. 하루에 여러 번 GitHub에서 새로 수집합니다.",
    "today.loading": "오늘의 목록을 불러오는 중…",
    "today.failed": "지금은 목록을 불러올 수 없습니다. <a href=\"https://github.com/trending\">GitHub Trending</a>에서 직접 확인해 보세요.",
    "today.updated": "{time} 수집",
    "today.stars": "오늘 +{n}",
    "features.eyebrow": "하는 일",
    "features.title": "한 시간 스크롤 대신, 커피 한 잔의 5분.",
    "f1.title": "메뉴 막대의 아침 브리핑",
    "f1.body": "하루 한 번 정한 시각에 오늘의 트렌드를 어제와 비교해 새로 올라오거나 순위가 오른 프로젝트만 보여줍니다. 관심 언어·키워드에 맞는 프로젝트가 맨 앞에 옵니다.",
    "f2.title": "내 언어로 읽기",
    "f2.body": "설명과 README 요약을 Mac에서 바로 번역합니다. 전체 README도 앱 안에서 열고, 프로젝트가 직접 쓴 번역본이 있으면 골라 볼 수 있습니다.",
    "f3.title": "눈에 띈 프로젝트 보관",
    "f3.body": "메모와 상태를 붙여 보관하세요. 보관한 프로젝트에 새 릴리스가 나오면 알려 주고, 목록을 마크다운으로 내보낼 수 있습니다.",
    "f4.title": "오래 가는 프로젝트 보기",
    "f4.body": "며칠째 목록에 올라 있는지와 최근 일주일 순위를 보여줍니다.",
    "f5.title": "원할 때만 AI 설명",
    "f5.body": "Apple Intelligence를 쓰는 Mac에서는 README를 기기 안에서 한국어로 요약할 수 있습니다. 나머지 기능은 AI 없이 동작합니다.",
    "privacy.eyebrow": "개인정보",
    "privacy.title": "내 목록은 내 Mac에만.",
    "privacy.p1": "계정 없음",
    "privacy.p2": "분석 도구 없음",
    "privacy.p3": "자체 서버 없음",
    "privacy.p4": "AI는 기기 안에서만",
    "privacy.body": "보관한 프로젝트·메모·번역·설명은 라이브러리 폴더의 파일로 남습니다. 앱은 공개 페이지만 읽습니다. 이 사이트의 트렌드 피드, 대체용 GitHub Trending, 그리고 열거나 보관한 프로젝트의 README·릴리스 페이지입니다. 이 사이트에도 쿠키나 추적 도구가 없습니다.",
    "install.eyebrow": "설치",
    "install.title": "명령어 한 줄.",
    "install.brew": "바로 열립니다. 업데이트는 앱 안에서 받거나 <code>brew upgrade</code>로 설치합니다.",
    "install.zip.title": "또는 ZIP",
    "install.zip.1": "<a href=\"https://github.com/ddingddong9/gitmorning/releases/latest\">최신 릴리스</a>에서 받아 GitMorning을 응용 프로그램 폴더로 옮깁니다.",
    "install.zip.2": "Apple 공증을 받지 않아 처음에는 macOS가 막습니다. <b>휴지통으로 이동</b>이 아니라 <b>완료</b>를 누르세요.",
    "install.zip.3": "<b>시스템 설정 → 개인정보 보호 및 보안</b>에서 <b>그래도 열기</b>를 누릅니다. 한 번만 하면 됩니다.",
    "faq.title": "자주 묻는 질문",
    "q1": "무료인가요?",
    "a1": "네. MIT 라이선스 오픈소스이고 유료 플랜·광고·API 키가 없습니다.",
    "q2": "왜 Apple 공증을 받지 않았나요?",
    "a2": "공증에는 유료 Apple Developer ID가 필요합니다. 대신 업데이트는 Ed25519 키로 서명하고 설치 전에 확인해, 변조된 업데이트는 설치되지 않습니다. 소스도 공개되어 있습니다.",
    "q3": "어떤 Mac에서 쓸 수 있나요?",
    "a3": "macOS 14 이상의 Apple Silicon Mac입니다. 번역은 macOS 15, 한국어 설명은 Apple Intelligence를 켠 macOS 26이 필요합니다.",
    "q4": "계속 켜 두어야 하나요?",
    "a4": "아침 브리핑과 릴리스 알림은 GitMorning이 실행 중일 때 동작합니다. 메뉴 막대에 두고 로그인 시 열기를 켜 두면 매일 아침 준비됩니다.",
    "q5": "목록은 어디서 오나요?",
    "a5": "github.com/trending입니다. 저장소의 워크플로가 하루에 여러 번 수집해 이 사이트에 올리고, 그 목록이 8시간보다 오래되면 앱이 GitHub를 직접 읽습니다.",
    "q6": "버그 신고나 기여는 어떻게 하나요?",
    "a6": "GitHub에 이슈나 PR을 올려 주세요. 한국어와 영어 모두 환영합니다.",
    "footer.releases": "릴리스",
    "footer.issues": "이슈",
    "footer.feed": "피드",
  };
  const en = {
    "copy": "Copy", "copied": "Copied",
    "today.failed": "The list is unavailable right now. See <a href=\"https://github.com/trending\">GitHub Trending</a> directly.",
    "today.updated": "Collected {time}",
    "today.stars": "+{n} today",
  };

  const nodes = [...document.querySelectorAll("[data-i18n]")];
  const english = new Map(nodes.map((node) => [node, node.innerHTML]));
  const images = [...document.querySelectorAll("img[data-ko-src]")];
  const englishSrc = new Map(images.map((img) => [img, img.getAttribute("src")]));
  let language = "en";
  let feed = null;

  const text = (key) => (language === "ko" ? ko[key] : en[key]) ?? en[key] ?? key;

  function stored() {
    try { return localStorage.getItem("language"); } catch { return null; }
  }
  function remember(value) {
    try { localStorage.setItem("language", value); } catch { /* private mode: keep it for this visit */ }
  }

  function apply(next) {
    language = next;
    document.documentElement.lang = next;
    for (const node of nodes) {
      const key = node.dataset.i18n;
      node.innerHTML = next === "ko" && ko[key] ? ko[key] : english.get(node);
    }
    for (const img of images) img.src = next === "ko" ? img.dataset.koSrc : englishSrc.get(img);
    document.getElementById("lang").textContent = next === "ko" ? "English" : "한국어";
    document.querySelectorAll(".copy:not(.done) .copy-label").forEach((label) => { label.textContent = text("copy"); });
    if (feed) render(feed);
  }

  document.getElementById("lang").addEventListener("click", () => {
    const next = language === "ko" ? "en" : "ko";
    remember(next);
    apply(next);
  });

  document.querySelectorAll(".copy").forEach((button) => {
    button.addEventListener("click", async () => {
      try { await navigator.clipboard.writeText(button.dataset.copy); } catch { return; }
      const label = button.querySelector(".copy-label");
      button.classList.add("done");
      label.textContent = text("copied");
      setTimeout(() => { button.classList.remove("done"); label.textContent = text("copy"); }, 1600);
    });
  });

  function ago(date) {
    const minutes = Math.round((date - Date.now()) / 60000);
    const format = new Intl.RelativeTimeFormat(language, { numeric: "auto" });
    if (Math.abs(minutes) < 60) return format.format(minutes, "minute");
    const hours = Math.round(minutes / 60);
    if (Math.abs(hours) < 48) return format.format(hours, "hour");
    return format.format(Math.round(hours / 24), "day");
  }

  function element(tag, className, content) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (content !== undefined) node.textContent = content;
    return node;
  }

  function render(data) {
    const list = document.getElementById("trending");
    const items = data.repositories.slice(0, 5).map((repo) => {
      const item = element("li");
      item.append(element("span", "rank", String(repo.rank)));
      const link = element("a", "repo");
      link.href = repo.url;
      link.append(element("span", "owner", repo.owner + " / "), document.createTextNode(repo.name));
      item.append(link);
      item.append(element("span", "gain", repo.periodStars == null ? "" :
        text("today.stars").replace("{n}", repo.periodStars.toLocaleString(language))));
      if (repo.description) item.append(element("p", "desc", repo.description));
      if (repo.language) item.append(element("span", "lang-tag", repo.language));
      return item;
    });
    list.replaceChildren(...items);
    const collected = new Date(data.collectedAt);
    document.getElementById("updated").textContent = isNaN(collected) ? "" : text("today.updated").replace("{time}", ago(collected));
  }

  async function load() {
    const sources = ["v1/daily-all.json", "https://ddingddong9.github.io/gitmorning/v1/daily-all.json"];
    for (const url of sources) {
      try {
        const response = await fetch(url, { cache: "no-cache" });
        if (!response.ok) continue;
        const data = await response.json();
        if (data.schemaVersion !== 1 || !Array.isArray(data.repositories) || !data.repositories.length) continue;
        feed = data;
        render(data);
        return;
      } catch { /* try the next source */ }
    }
    const list = document.getElementById("trending");
    const item = element("li", "placeholder");
    item.innerHTML = text("today.failed");
    list.replaceChildren(item);
  }

  const preferred = stored() ?? ((navigator.language || "").toLowerCase().startsWith("ko") ? "ko" : "en");
  apply(preferred);
  load();
})();
