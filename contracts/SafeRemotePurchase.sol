// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;
contract RemoteSafeTradingEcommerse {
    uint public productCount;
    uint public purchaseCount; 

    struct Product {
        uint productId;
        address seller;
        string sellerName;
        string name; 
        uint priceInWei;
        string description;
        string image;
        string category;
    }

    struct Purchase {
        uint purchaseId;
        address buyer;
        address seller;
        uint productId;
        uint quantity;
        State status;
        uint requiredDepositBuyerInWei;
        uint requiredDepositSellerInWei;
    }

    Product[] public productListings;

    mapping(address => Product[]) public sellerListings;
    mapping(uint => Purchase) public purchaseHistory;

    enum State {ShowedInterest,Created,Locked,Release,Inactive,Complete}

    /// Only the buyer can call this function.
    error OnlyBuyer();
    /// Only the seller can call this function.
    error OnlySeller();
    /// The function cannot be called at the current state.
    error InvalidState();
    /// The provided value has to be even.
    error ValueNotEven();
    /// The value deposited is not sufficient
    error InsufficientDeposit();
    /// Teller can not buy his own product
    error SellerCanNotBuyOwnProduct();
    /// This purchase transaction no longer exists
    error PurchaseTransactionNoLongerExist();

    event Aborted();
    event PurchaseConfirmed();
    event ItemReceived();
    event SellerRefunded();

    // emit new event when new product created
    // Define the event
    event ProductCreated(
        uint indexed productId,
        address indexed seller,
        string seller_name,
        string name,
        uint price,
        string description,
        string image,
        string category
    );


    // create a function to add a new product created to total product listing and seller listing
    function createProduct(
        string memory _sellerName,
        string memory _name,
        uint _priceInWei,
        string memory _description,
        string memory _image,
        string memory _category
    ) external {
        productCount++;
        Product memory newProduct = Product({
            productId: productCount,
            seller: msg.sender,
            sellerName: _sellerName,
            name: _name,
            priceInWei: _priceInWei,
            description: _description,
            image: _image,
            category: _category
        });

        productListings.push(newProduct);
        sellerListings[msg.sender].push(newProduct);

        // Emit the event
        emit ProductCreated(
            newProduct.productId,
            newProduct.seller,
            newProduct.sellerName,
            newProduct.name,
            newProduct.priceInWei,
            newProduct.description,
            newProduct.image,
            newProduct.category
        );
    }

    
    event PurchaseCreated(
        uint indexed purchaseId,
        address indexed buyer,
        address indexed seller,
        uint productId,
        uint quantity,
        State status
    );


    // buyer click to show interest for the product
    function buyerIndicateInterestToBuyProduct(uint _productId, uint _quantity) external {
        require(_productId > 0 && _productId <= productCount, "Product does not exist");

        Product memory product = productListings[_productId - 1];

        if(msg.sender == product.seller) {
            revert SellerCanNotBuyOwnProduct();
        }

        purchaseCount++;


        Purchase memory newPurchase = Purchase({
            purchaseId: purchaseCount,
            buyer: msg.sender,
            seller: product.seller,
            productId: _productId,
            quantity: _quantity,
            status: State.ShowedInterest,
            requiredDepositBuyerInWei:_quantity*product.priceInWei*3,
            requiredDepositSellerInWei:_quantity*product.priceInWei*2
        });

        purchaseHistory[purchaseCount]=newPurchase;

        emit PurchaseCreated(
            newPurchase.purchaseId,
            newPurchase.buyer,
            newPurchase.seller,
            newPurchase.productId,
            newPurchase.quantity,
            newPurchase.status
        );
    }

    // get purchase by id
    function getPurchaseByID(
        uint _purchase_id
    )
        external 
        view
        returns 
        (Purchase memory)
    {
        return purchaseHistory[_purchase_id];
    }

    // seller lock in ether to confirm buyer interest and create a product transaction
    function sellerAcknowledgeBuyerInterest(
        uint _purchase_id
    )
        external 
        payable 
    {
        Purchase storage purchase=purchaseHistory[_purchase_id];

        if(purchase.seller == address(0)) {
            revert PurchaseTransactionNoLongerExist();  
        }
        
        if (purchase.status!=State.ShowedInterest){
            revert InvalidState();
        }

        if(msg.sender != purchase.seller){
            revert OnlySeller();
        }

        if(msg.value != purchase.requiredDepositSellerInWei) {
            revert InsufficientDeposit();
        }

        purchase.status=State.Created;
    }

     // seller lock in ether to confirm buyer interest and create a product transaction
    function buyerDiscardInterestForProduct(
        uint _purchase_id
    )
        external  
    {
        Purchase storage purchase=purchaseHistory[_purchase_id];
        if (purchase.status!=State.ShowedInterest){
            revert InvalidState();
        }

        if(msg.sender != purchase.buyer){
            revert OnlyBuyer();
        }

        delete purchaseHistory[_purchase_id];
    }

    // seller can abort the purchase transaction to reclaim ethers 
    function sellerAbortPurchaseBeforeAcknowledge(uint _purchase_id) 
        external
    {
        Purchase storage purchase=purchaseHistory[_purchase_id];
        if (purchase.status!=State.ShowedInterest){
            revert InvalidState();
        }

        if(msg.sender != purchase.seller){
            revert OnlySeller();
        }

        purchase.status=State.Inactive;
    }

    // seller can abort the purchase transaction to reclaim ethers 
    function sellerAbortPurchaseAfterAcknowledge(uint _purchase_id) 
        external
    {
        Purchase storage purchase=purchaseHistory[_purchase_id];
        if (purchase.status!=State.Created){
            revert InvalidState();
        }

        if(msg.sender != purchase.seller){
            revert OnlySeller();
        }

        purchase.status=State.Inactive;

        payable(msg.sender).transfer(purchase.requiredDepositSellerInWei);
    }

    // buyer confirm purchase 
    function buyerConfirmPurchase(
        uint _purchase_id 
    )
        external
        payable
    {
        Purchase storage purchase=purchaseHistory[_purchase_id];
        if (purchase.status!=State.Created){
            revert InvalidState();
        }

        if(msg.sender != purchase.buyer){
            revert OnlyBuyer();
        }

        if(msg.value != purchase.requiredDepositBuyerInWei) {
            revert InsufficientDeposit();
        }

        purchase.status=State.Locked;
    }

    // buyer confirm receiving of product
    function buyerConfirmReceivingProduct(
        uint _purchase_id 
    )
        external
    {
        Purchase storage purchase=purchaseHistory[_purchase_id];
        if (purchase.status!=State.Locked){
            revert InvalidState();
        }

        if(msg.sender != purchase.buyer){
            revert OnlyBuyer();
        }

        purchase.status=State.Release;

        payable(msg.sender).transfer(purchase.requiredDepositSellerInWei);
    }

    // buyer click to reclaim the fund and get money for their product
    function sellerReclaimDepositPlusProductPayment(
        uint _purchase_id 
    )
        external
    {
        Purchase storage purchase=purchaseHistory[_purchase_id];
        if (purchase.status!=State.Release){
            revert InvalidState();
        }

        if(msg.sender != purchase.seller){
            revert OnlyBuyer();
        }

        purchase.status=State.Complete;

        payable(msg.sender).transfer(purchase.requiredDepositBuyerInWei);
    }

    // return all products belong to a seller 
    function returnAllProductsBelongToSeller()
    external
    view 
    returns (Product[] memory)
    {
        return sellerListings[msg.sender];
    }

    // return all products
    function returnAllProducts()
    external
    view 
    returns (Product[] memory)
    {
        return productListings;
    }


    // return all transactions belong to a buyer
    // Function to get all purchase with a specific price
    function getPurchaseTransactionBuyer(address buyerAddress) 
    external 
    view 
    returns 
    (Purchase[] memory) {
        uint count = 0;
        // First, count how many products match the criteria
        for (uint i = 1; i < purchaseCount+1; i++) {
            if (purchaseHistory[i].buyer == buyerAddress) {
                count++;
            }
        }

        // Allocate memory for the result array
        Purchase[] memory matchingPurchase = new Purchase[](count);
        uint index = 0;

        // Now, collect the products that match the price
        for (uint i = 1; i < purchaseCount+1; i++) {
            if (purchaseHistory[i].buyer == buyerAddress) {
                matchingPurchase[index] = purchaseHistory[i];
                index++;
            }
        }

        return matchingPurchase;
    }

      // Function to get all purchase with a specific seller
    function getPurchaseTransactionSeller(address sellerAddress) 
    external 
    view 
    returns 
    (Purchase[] memory) {
        uint count = 0;
        // First, count how many products match the criteria
        for (uint i = 1; i < purchaseCount+1; i++) {
            if (purchaseHistory[i].seller == sellerAddress) {
                count++;
            }
        }

        // Allocate memory for the result array
        Purchase[] memory matchingPurchase = new Purchase[](count);
        uint index = 0;

        // Now, collect the products that match the price
        for (uint i = 1; i < purchaseCount+1; i++) {
            if (purchaseHistory[i].seller == sellerAddress) {
                matchingPurchase[index] = purchaseHistory[i];
                index++;
            }
        }

        return matchingPurchase;
    }
}