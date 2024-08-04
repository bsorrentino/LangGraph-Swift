import UIKit

struct Channel<T> {
    var value: T
    
}

func update<T>( channel: Channel<T>,  newValue: Any ) throws -> Any {
    print( "update single \(newValue)" )
    
    return newValue
}

func update<T>( channel: Channel<[T]>, newValue: Any ) throws -> Any  {
    print( "update array \(newValue)" )
    
    return newValue
}


let channel = Channel(value: [ "1", "2", "3" ])

try update(channel: channel, newValue: [])

let channel1 = Channel(value: "BBBBB")

try update(channel: channel1, newValue: "CCCCC")
