import Testing
@testable import Git2
import Cgit2

@Suite
struct TreeEntryFileModeRawTests {
    @Test
    func roundTripCoversEveryCase() {
        let cases: [(TreeEntry.FileMode, git_filemode_t)] = [
            (.tree,            GIT_FILEMODE_TREE),
            (.blob,            GIT_FILEMODE_BLOB),
            (.blobExecutable,  GIT_FILEMODE_BLOB_EXECUTABLE),
            (.link,            GIT_FILEMODE_LINK),
            (.commit,          GIT_FILEMODE_COMMIT),
        ]
        for (mode, expectedRaw) in cases {
            #expect(mode.raw == expectedRaw)
            #expect(TreeEntry.FileMode.from(expectedRaw) == mode)
        }
    }
}
