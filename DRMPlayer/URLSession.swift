import Foundation

extension URLSession {
    func data(with url: URL, completion: @escaping (Result<Data, Error>) -> Void) -> URLSessionDataTask {
        data(with: URLRequest(url: url), completion: completion)
    }

    func data(with request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) -> URLSessionDataTask{
        dataTask(with: request) { data, _, error in
            if let error {
                completion(.failure(error))
            }
            else if let data {
                completion(.success(data))
            }
        }
    }
}
