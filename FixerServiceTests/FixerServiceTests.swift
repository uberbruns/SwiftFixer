//
//  FixerServiceTests.swift
//  FixerServiceTests
//
//  Created by Karsten Bruns on 22/09/15.
//  Copyright © 2015 grandcentrix GmbH. All rights reserved.
//

import XCTest
@testable import FixerService

class FixerServiceTests: XCTestCase {
    
    let service = FixerService()

    func testLatest() {
        
        let expectation = self.expectationWithDescription("Receive Latest Rates")
        let request = LatestRequest(base: "USD", symbols: "EUR", "GBP")

        service.runRequest(request) { (response) -> () in
            expectation.fulfill()
            
            switch response {
            case .Result(let result) :
                XCTAssert(result.rates["EUR"] != nil, "Result Received")
                XCTAssertEqual(result.base, "USD")
            default :
                XCTFail("Result Received")
            }

        }
        
        self.waitForExpectationsWithTimeout(60, handler: nil)
    }

    
    
    func testHistorical() {
        
        let expectation = self.expectationWithDescription("Receive Latest Rates")
        let request = HistoricalRatesRequest(date: "2014-05-03", base: "RON", symbols: "EUR", "USD")
        
        service.runRequest(request) { (response) -> () in
            expectation.fulfill()
            
            switch response {
            case .Result(let result) :
                XCTAssert(result.rates["EUR"] != nil, "Result Received")
                XCTAssertEqual(result.base, "RON")
            default :
                XCTFail("Result Received")
            }
            
        }
        
        self.waitForExpectationsWithTimeout(60, handler: nil)
    }
    
}
