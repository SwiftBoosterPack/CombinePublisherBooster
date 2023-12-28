# CombinePublisherBooster
Adds additional support for publishers which exist in RxSwift but not Combine

## WithLatestFrom

[See marbles](https://rxmarbles.com/#withLatestFrom) for explanation.

Provides an extension on Combine `Publisher` to allow calling `withLatestFrom(otherPublisher)`

```swift
func getData() -> AnyPublisher<(String, Int?), Never> {
  let stringPublisher: AnyPublisher<String, Never> = getStringPublisher()
  let integerPublisher: AnyPublisher<Int, Never> = getIntegerPublisher()

  // We want the string content to trigger the pipeline, with whatever the latest value integer is.
  return stringPublisher.withLatestFrom(integerPublisher)
}
```

Assuming we received the following values...
```
00:00:01 - stringPublisher receives "ONE"
00:00:02 - stringPublisher receives "TWO"
00:00:03 - integerPublisher receives 1
00:00:04 - integerPublisher receives 2
00:00:05 - stringPublisher receives "THREE"
00:00:06 - integerPublisher receives 3
```

We would expect to receive the following outputs...
```
00:00:01 - ("ONE", nil)
00:00:02 - ("TWO", nil)
00:00:05 - ("THREE", 2)
```
