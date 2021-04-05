//
//  Utilities.swift
//  Chirp
//
//  Created by Tim Sweeney on 4/4/21.
//

import Foundation

public final class Utilities{
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        return formatter
    }()
    
}




