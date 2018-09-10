'use strict';

/**
 * Order transaction logic
 */

/**
 * Make an Order
 * @param {org.eyes.znueni.Order} order - the order transaction
 * @transaction
 * @return {Object}
 */
function order(order) {

    /**
     *
     * @param namespace
     * @constructor
     */
    var Order = function (namespace) {
        this.namespace = namespace;
        this.shoppingListRegistry = null;
        this.shoppingList = null;
        return this.init();
    };

    /**
     * Order Object
     */
    Order.prototype = Object.assign(Order.prototype, {
        /**
         * constructor
         */
        init: function () {
            return getAssetRegistry(this.namespace)
                .then(this.getShoppingListRegistry.bind(this))
                .then(this.getShoppingList.bind(this))
                .then(this.doOrder.bind(this))
                .catch(function (error) {
                    throw new Error('Transaction (Order) process failed: ' + error);
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
         *
         */
        getShoppingList: function () {
            return query('selectOpenShoppingList')
                .then(function (queryResult) {
                    switch (queryResult.length) {
                        case 0:
                            var shoppingListId = this.generateRandom();
                            return query('selectShoppingListById', {id: shoppingListId})
                                .then(function (result) {
                                    if (result.length === 0) {
                                        this.shoppingList = getFactory().newResource('org.eyes.znueni', 'ShoppingList', shoppingListId);
                                        this.shoppingList.state = 'NEW';
                                        this.shoppingList.orders = [];
                                        this.emitAddShoppingListNotification(this.shoppingList);
                                    } else {
                                        return this.getShoppingList();
                                    }
                                }.bind(this));
                        case 1:
                            this.shoppingList = queryResult[0];
                            break;
                        default:
                            throw new Error('Getting shopping list failed. ');
                    }
                }.bind(this))
                .catch(function (error) {
                    throw new Error('getShoppingList: ' + error);
                });

        },

        /**
         * @returns {Promise}
         */
        doOrder: function () {

            if (this.shoppingList === null) {
                throw new Error('No shopping list found. ');
            }

            if (this.shoppingList.state === 'CLOSED') {
                throw new Error('Shopping list is closed. ');
            }

            this.shoppingList.orders.push(order);

            if (this.shoppingList.state === 'NEW') {
                this.shoppingList.state = 'OPEN';
                return this.shoppingListRegistry.add(this.shoppingList);
            } else {
                return this.shoppingListRegistry.update(this.shoppingList);
            }
        }
    });

    return new Order('org.eyes.znueni.ShoppingList');
}
