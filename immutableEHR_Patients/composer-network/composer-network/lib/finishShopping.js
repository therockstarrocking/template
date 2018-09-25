'use strict';

/**
 * FinishShopping transaction logic
 */

/**
 * Finish shopping
 * @param {org.eyes.znueni.FinishShopping} tx - finish shopping transaction
 * @transaction
 * @return {Object}
 */
function finishShopping(tx) {

    /**
     * @param namespace
     * @constructor
     */
    var FinishShopping = function (namespace) {
        this.namespace = namespace;
        this.shoppingListRegistry = null;
        return this.init();
    };

    /**
     * FinishShopping Object
     */
    FinishShopping.prototype = Object.assign(FinishShopping.prototype, {
        /**
         * constructor
         */
        init: function () {
            return getAssetRegistry(this.namespace)
                .then(this.getShoppingListRegistry.bind(this))
                .then(this.doFinishShopping.bind(this))
                .then(this.openNewShoppingList.bind(this))
                .catch(function (error) {
                    throw new Error('Transaction (FinishSopping) process failed: ' + error);
                });
        },

        /**
         * @param shoppingListRegistry
         */
        getShoppingListRegistry: function (shoppingListRegistry) {
            this.shoppingListRegistry = shoppingListRegistry;
        },


        /**
         *
         * @param shoppingList
         */
        emitAddShoppingListNotification: function (shoppingList) {
            // emit a notification that a shopping list was added
            var addShoppingListNotification = getFactory().newEvent('org.eyes.znueni', 'addShoppingListNotification');
            addShoppingListNotification.shoppingList = shoppingList;
            emit(addShoppingListNotification);
        },

        /**
         * generate random
         * @returns {string}
         */
        generateRandom: function () {
            // current timestamp as string
            var date = String(Date.now());
            // Math.random should be unique because of its seeding algorithm.
            // Convert it to base 36 (numbers + letters), and grab the first 9 characters
            // after the decimal.
            var random1 = Math.random().toString(36).substr(2, 9);
            var random2 = Math.random().toString(36).substr(2, 9);
            return random1.concat(date.concat(random2));
        },

        /**
         * finish shopping
         */
        doFinishShopping: function () {
            var shoppingList = tx.shoppingList;
            if (shoppingList.state !== 'OPEN') {
                throw new Error('Shopping list not open');
            }
            return getParticipantRegistry('org.eyes.znueni.User')
                .then(function (userRegistry) {
                    var buyers = [];
                    if (shoppingList.orders && shoppingList.orders.length > 0) {
                        for (var i = 0; i < shoppingList.orders.length; i++) {
                            var buyer = shoppingList.orders[i].user;
                            var balance = buyer.balance - (shoppingList.orders[i].product.price * shoppingList.orders[i].amount);
                            buyer.balance = Math.round(balance * 100) / 100;
                            buyers.push(userRegistry.update(buyer));
                        }
                    }
                    return Promise.all(buyers);
                })
                .then(function () {
                    shoppingList.state = 'CLOSED';
                    return this.shoppingListRegistry.update(shoppingList);
                }.bind(this))
                .catch(function (error) {
                    throw new Error('doFinishShopping: ' + error);
                });
        },

        /**
         * new shopping list
         */
        openNewShoppingList: function () {
            var shoppingListId = this.generateRandom();
            return query('selectShoppingListById', {id: shoppingListId})
                .then(function (result) {
                    if (result.length === 0) {
                        var newShoppingList = getFactory().newResource('org.eyes.znueni', 'ShoppingList', shoppingListId);
                        newShoppingList.state = 'OPEN';
                        newShoppingList.orders = [];
                        this.emitAddShoppingListNotification(newShoppingList);
                        return this.shoppingListRegistry.add(newShoppingList);
                    } else {
                        return this.openNewShoppingList();
                    }
                }.bind(this))
                .catch(function (error) {
                    throw new Error('openNewShoppingList: ' + error);
                });
        }
    });

    return new FinishShopping('org.eyes.znueni.ShoppingList');
}
