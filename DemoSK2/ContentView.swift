//
//  ContentView.swift
//  DemoSK2
//
//  Created by HoanNL on 21/08/2023.
//

import SwiftUI
import StoreKit


struct ProductList: View {
    @EnvironmentObject var vm: ViewModel
    
    var products: [Product]
    var title: String
    
    var body: some View {
        Section {
            ForEach(products, id: \.id) { product in
                Button {
                    Task {
                        do {
                            try await vm.purchase(product)
                        } catch {
                            debugPrint(error)
                        }
                    }
                } label: {
                    Text(product.id + " - \(product.type)")
                }.frame(maxWidth: .infinity, minHeight: 50)
            }
        } header: {
            Text(title)
        }
    }
}

struct PurchasedProductList: View {
    @EnvironmentObject var vm: ViewModel
    
    var products: [Product]
    var title: String
    
    var body: some View {
        Section {
            ForEach(products, id: \.id) { product in
                Text(product.id + " - \(product.type)")
            }
        } header: {
            Text(title)
        }
    }
}

struct ContentView: View {
    
    @EnvironmentObject var vm: ViewModel
    
    var body: some View {
        ScrollView {
            ProductList(products: vm.autoRenewables, title: "RENEWABLES")
            ProductList(products: vm.nonRenewables, title: "NoN_RENEWABLES")
            ProductList(products: vm.consumables, title: "CONSUM")
            ProductList(products: vm.nonConsumables, title: "Non_CONSUM")
            Section("Transactions") {
                ForEach(vm.publishedConsumableTransactionIDs, id: \.hashValue) { ele in
                    Text("\(ele)")
                }
            }
            
            PurchasedProductList(products: vm.purchasedNonConsumables, title: "purchasedNonConsumables".uppercased())
            PurchasedProductList(products: vm.purchasedAutoRenewables, title: "purchasedAutoRenewables".uppercased())
            PurchasedProductList(products: vm.purchasedNonRenewables, title: "purchasedNonRenewables".uppercased())
        }
    }
}



#Preview {
    ContentView().environmentObject(ViewModel())
}
