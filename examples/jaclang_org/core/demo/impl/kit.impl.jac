impl Card(children: any) -> JsxElement {
    return <div className="demo-card">{children}</div>;
}

impl Line(children: any) -> JsxElement {
    return <div className="demo-line">{children}</div>;
}

impl Title(children: any) -> JsxElement {
    return <div className="demo-title">{children}</div>;
}

impl Label(children: any) -> JsxElement {
    return <span>{children}</span>;
}

impl Btn(label: str, press: Callable) -> JsxElement {
    return <button className="demo-btn" onClick={press}>{label}</button>;
}
