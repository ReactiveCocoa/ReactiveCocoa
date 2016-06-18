# Documenting Code

Follow these rules when documenting code using Xcode's markup:

- Expand lines up to 80 characters per line. If the line extends beyond 80 characters the next line must be indented at the previous markup token's colon position + 1 space:

```
/// DO:
/// For the sake of the demonstration we will use the lorem ipsum text here.
/// Lorem ipsum dolor sit amet, consectetur adipiscing elit. Proin ullamcorper 
/// tempor dolor a cras amet.
///
/// - returns: Cras a convallis dolor, sed pellentesque mi. Integer suscipit
///            fringilla turpis in bibendum volutpat.
/// ...
/// DON'T
/// Lorem ipsum dolor sit amet, consectetur adipiscing elit. Proin ullamcorper tempor dolor a cras amet.
///
/// - returns: Cras a convallis dolor, sed pellentesque mi. Integer suscipit fringilla turpis in bibendum volutpat.
/// ...
/// DON'T II
/// Lorem ipsum dolor sit amet, consectetur adipiscing elit. Proin ullamcorper 
/// tempor dolor a cras amet.
///
/// - returns: Cras a convallis dolor, sed pellentesque mi. Integer suscipit
/// fringilla turpis in bibendum volutpat.
```

- Always use `parameters` instead of `parameter` even if function has one parameter:

```
/// DO:
/// - parameters:
///   - foo: Instance of `Foo`.
/// DON'T:
/// - parameter foo: Instance of `Foo`.
```

- Do not add any `return` token to initializers' markup:

```
/// DO:
/// Initialises instance of `Foo` with given arguments.
init(withBar bar: Bar = Bar.defaultBar()) {
    ...
/// DON'T:
/// Initialises instance of `Foo` with given arguments.
///
/// - returns: Initialized `Foo` with default `Bar`
init(withBar bar: Bar = Bar.defaultBar()) {
    ...
```

- Treat parameter declaration as a separate sentence/paragraph:

```
/// DO:
/// - parameters:
///   - foo: A foo for the function.
/// ...
/// DON'T:
/// - parameters:
///   - foo: foo for the function;
```

- Add one line between markup tokens and no whitespace lines between function's `parameters`:

```
/// DO:
/// - note: This is amazing function.
///
/// - parameters:
///   - foo: Instance of `Foo`.
///   - bar: Instance of `Bar`.
///
/// - returns: Something magical.
/// ...
/// DON'T:
/// - note: Don't forget to breathe.
/// - parameters:
///   - foo: Instance of `Foo`.
///   - bar: Instance of `Bar`.
/// - returns: Something claustrophobic.
```
