import Foundation


public enum CheckpointError: Error, LocalizedError {
    
    case missingThreadIdentifier(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingThreadIdentifier(let message):
            return message
        }
    }

}

/// Represents a checkpoint of an agent state.
///
/// The checkpoint is an immutable object that holds an agent state
/// and a string that represents the next state.
/// It is designed to be serializable and restorable.
public struct Checkpoint : Equatable  {
    
    public static func == (lhs: Checkpoint, rhs: Checkpoint) -> Bool {
        lhs.id == rhs.id
    }
    
    /// A unique identifier for the checkpoint.
    public let id: UUID
    /// The agent's state at the time of the checkpoint.
    public var state: [String: Any]
    /// The identifier of the node where the checkpoint was created.
    public var nodeId: String
    /// The identifier of the next node to execute after this checkpoint.
    public var nextNodeId: String
    
    /// Creates a new `Checkpoint` with the given state and node information.
    ///
    /// - Parameters:
    ///   - state: The current agent state.
    ///   - nodeId: The current node identifier.
    ///   - nextNodeId: The identifier of the next node.
    public init( state: [String: Any], nodeId: String, nextNodeId: String) {
        self.id = UUID()
        self.state = state
        self.nodeId = nodeId
        self.nextNodeId = nextNodeId
    }

    /// Updates the checkpoint's state with a partial update and communication channels.
    ///
    /// - Parameters:
    ///   - values: A partial agent state used to update the existing state.
    ///   - channels: A set of channels available to the agent during update.
    /// - Returns: A new `Checkpoint` instance with the updated state.
    /// - Throws: An error if the state update fails.
    public func updateState(values: PartialAgentState, channels: Channels) throws -> Self {
        
        var editable = self
        editable.state = try LangGraph.updateState(currentState: self.state , partialState: values , channels: channels)
        return editable
    }
}

extension Checkpoint: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case state
        case nodeId
        case nextNodeId
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        state = try container.decode([String: LangGraph.AnyDecodable].self, forKey: .state).mapValues { $0.value }
        nodeId = try container.decode(String.self, forKey: .nodeId)
        nextNodeId = try container.decode(String.self, forKey: .nextNodeId)
    }
    
    public func encode(to encoder: any Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode( toEncodableStateData(data: state), forKey: .state)
        try container.encode(nodeId, forKey: .nodeId)
        try container.encode(nextNodeId, forKey: .nextNodeId)
        
    }
}

/// Represents the result of a checkpoint release operation, including the thread identifier and associated checkpoints.
public struct Tag {
    /// The identifier of the thread whose checkpoints were released.
    public let threadId: String

    /// A collection of checkpoints that were associated with the thread.
    public let checkpoints: AnyCollection<Checkpoint>
}

/// A protocol that defines an interface for saving and retrieving `Checkpoint` instances.
///
/// Conforming types manage checkpoint data associated with a specific `RunnableConfig`,
/// allowing retrieval, update, listing, and release of checkpoints. This protocol enables
/// persistence strategies to be customized for different runtime environments or threading models.
public protocol CheckpointSaver {
    /// Returns all checkpoints associated with the provided `RunnableConfig`.
    ///
    /// - Parameter config: The configuration that identifies the context or thread.
    /// - Returns: A collection of `Checkpoint` instances.
    func list(config: RunnableConfig) -> AnyCollection<Checkpoint>;

    /// Retrieves a specific checkpoint based on the provided `RunnableConfig`.
    ///
    /// If `checkpointId` is set in the configuration, the corresponding checkpoint is returned.
    /// Otherwise, returns the latest checkpoint for the context.
    ///
    /// - Parameter config: The configuration that may include a specific checkpoint identifier.
    /// - Returns: The requested `Checkpoint` instance, or `nil` if not found.
    func get(config: RunnableConfig) ->  Checkpoint?;

    /// Persists a new checkpoint or updates an existing one based on the configuration.
    ///
    /// If the `checkpointId` is set in the configuration, the checkpoint with that ID is updated.
    /// Otherwise, the new checkpoint is added to the thread's checkpoint stack.
    ///
    /// - Parameters:
    ///   - config: The configuration identifying the context or thread.
    ///   - checkpoint: The checkpoint to be saved or updated.
    /// - Returns: A modified `RunnableConfig` reflecting the new checkpoint ID.
    /// - Throws: An error if the checkpoint cannot be persisted.
    func put(config: RunnableConfig,  checkpoint: Checkpoint) throws -> RunnableConfig;

    /// Releases all checkpoints associated with the provided `RunnableConfig`.
    ///
    /// This method is responsible for cleanup of checkpoints tied to a specific context or thread.
    ///
    /// - Parameter config: The configuration identifying the context or thread.
    /// - Returns: A `Tag` representing the final state of the thread's checkpoints.
    /// - Throws: An error if the release operation fails.
    func release(config: RunnableConfig) throws -> Tag;
}

extension CheckpointSaver {
    @inline(__always) func THREAD_ID_DEFAULT() -> String { "$default" };
    
    @inline(__always) public func last( config: RunnableConfig ) ->  Checkpoint? {
        list( config: config ).first
    }
}

struct Stack<T>  {
    var elements: [T] = []

    var isEmpty: Bool {
        return elements.isEmpty
    }

    var count: Int {
        return elements.count
    }

    mutating func push(_ value: T) {
        elements.append(value)
    }

    mutating func pop() -> T? {
        return elements.popLast()
    }

    func peek() -> T? {
        return elements.last
    }
}


extension Stack: Sequence {
    public func makeIterator() -> IndexingIterator<Array<T>> {
        return elements.reversed().makeIterator()
    }
}

extension Stack {
    
    subscript(id: UUID) -> T? where T == Checkpoint {
        get {
            return elements.first { $0.id == id }
        }
        set(newValue) {
            guard let newValue else {
                fatalError( "Cannot set checkpoint with id \(id) to nil")
            }
            
            guard let index = elements.firstIndex(where: { $0.id == id }) else {
                fatalError( "Cannot find checkpoint with id \(id)" )
            }
            
            elements[index] = newValue
        }
    }
}

/// An in-memory implementation of `CheckpointSaver` for managing checkpoints by thread.
///
/// This class stores checkpoints in a dictionary keyed by thread identifiers and provides
/// basic operations for persisting, retrieving, listing, and releasing checkpoints.
/// It is primarily intended for use in testing or lightweight execution environments.
public class MemoryCheckpointSaver: CheckpointSaver {
    var checkpointsByThread: [String: Stack<Checkpoint>] = [:];

    public init() {}
    
    private func checkpoints(config: RunnableConfig ) -> Stack<Checkpoint> {
        let threadId = config.threadId ?? THREAD_ID_DEFAULT()
            
        guard let result = self.checkpointsByThread[threadId] else {
            let result = Stack<Checkpoint>();
            self.checkpointsByThread[threadId] = result;
            return result;
        }
        return result

    }
    
    private func updateCheckpoint( config: RunnableConfig, checkpoints: Stack<Checkpoint>  ) {
        let threadId = config.threadId ?? THREAD_ID_DEFAULT()
        
        self.checkpointsByThread[threadId] = checkpoints
    }
    
    public func get(config: RunnableConfig) -> Checkpoint? {
        let checkpoints = checkpoints(config: config);
        
        guard let checkpointId = config.checkpointId else {
            return checkpoints.peek()
        }
        
        return checkpoints.first(where: { $0.id == checkpointId })
    }
    
    public func put(config: RunnableConfig, checkpoint: Checkpoint) throws -> RunnableConfig {
        var checkpoints = checkpoints(config: config);
        
        if let checkpointId = config.checkpointId, checkpointId == checkpoint.id {
            
            checkpoints[checkpointId] = checkpoint
        }
        
        checkpoints.push(checkpoint)
        
        updateCheckpoint( config: config, checkpoints: checkpoints )
        
        return config.with {
            $0.checkpointId = checkpoint.id
        }
        
    }
    
    @discardableResult
    public func release(config: RunnableConfig) throws -> Tag {
        let threadId = config.threadId ?? THREAD_ID_DEFAULT()
        
        guard let removedCheckpoints = self.checkpointsByThread.removeValue(forKey: threadId) else {
            throw CheckpointError.missingThreadIdentifier("No checkpoint found for thread \(threadId)")
        }
        
        return Tag( threadId: threadId, checkpoints: AnyCollection(removedCheckpoints.elements) )
    }
    
    public func list(config: RunnableConfig) -> AnyCollection<Checkpoint> {
        let checkpoints = checkpoints(config: config);
        
        return AnyCollection(checkpoints.elements.reversed())
    }
}
