import UIKit

extension UIImage {
    static func namedFromBundle(_ name: String, ext: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}
