impl sleep(ms: int) {
    await new(
        Promise,
        lambda (resolve: any, _reject: any) {
            _ = setTimeout(lambda { resolve.call(None, True) }, ms);
        },
    );
}
