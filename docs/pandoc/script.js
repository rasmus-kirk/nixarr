addEventListener('DOMContentLoaded', () => {
  const fullpath = location.origin + location.pathname.replace(/\/$/, "");

  document.querySelectorAll('nav a').forEach((el) => {
    const url = new URL(el.href);
    const fullurl = url.origin + url.pathname.replace(/\/$/, "");
    console.log("fullurl", fullurl);
    console.log("fullpath", fullpath);
    console.log("locationpathname", location.pathname);
    console.log("urlpathname", url.pathname);
    const onHome = fullpath === location.origin
    const urlIsHome = fullurl === location.origin
    console.log("onhome", onHome);
    console.log("urlIsHome", urlIsHome);
    console.log("")

    if (onHome && fullurl === fullpath) {
      el.classList.add('active');
    }
    // The startsWith is for subpages
    else if (!urlIsHome && fullpath.startsWith(fullurl)) {
      el.classList.add('active');
    }
  });
});
