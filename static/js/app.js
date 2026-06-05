const el = document.getElementById("health");

fetch("/api/health")
  .then((r) => r.json())
  .then((d) => {
    el.textContent = JSON.stringify(d);
    el.classList.add("ok");
  })
  .catch(() => {
    el.textContent = "offline";
    el.classList.add("err");
  });
