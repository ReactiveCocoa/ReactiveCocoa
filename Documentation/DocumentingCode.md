# Documenting Code

Please follow these guidelines when documenting code using [Xcode's markup](https://developer.apple.com/library/mac/documentation/Xcode/Reference/xcode_markup_formatting_ref/):

- Expand lines up to 80 characters per line. If the line extends beyond 80 characters the next line must be indented at the previous markup delimiter's colon position + 1 space:

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

- Always use the `parameters` delimiter instead of the `parameter` delimiter even if a function has only one parameter:

```
/// DO:
/// - parameters:
///   - foo: Instance of `Foo`.
/// DON'T:
/// - parameter foo: Instance of `Foo`.
```

- Do not add a `return` delimiter to an initializer's markup:

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

- Add one line between markup delimiters and no whitespace lines between a function's `parameters`:

```
/// DO:
/// - note: This is an amazing function.
///
/// - parameters:
///   - foo: Instance of `Foo`.
///   - bar: Instance of `Bar`.
///
/// - returns: Something magical.
/// ...
/// DON'T:
/// - note: Don't forget to breathe, it's important! 😎
/// - parameters:
///   - foo: Instance of `Foo`.
///   - bar: Instance of `Bar`.
/// - returns: Something claustrophobic.
```
