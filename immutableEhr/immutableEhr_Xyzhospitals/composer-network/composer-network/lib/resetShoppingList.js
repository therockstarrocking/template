'use strict';

/**
 * ResetShoppingList transaction logic
 */

/**
 * Finish shopping
 * @param {org.eyes.znueni.ResetShoppingList} tx - reset shopping list transaction
 * @transaction
 * @return {Object}
 */
function resetShoppingList(tx) {

    /**
     * @param namespace
     * @constructor
     */
    var ResetShopping = function (namespace) {
        this.namespace = namespace;
        this.shoppingListRegistry = null;
        return this.init();
    };

    /**
     * ResetShopping Object
     */
    ResetShopping.prototype = Object.assign(ResetShopping.prototype, {
        /**
         * constructor
         */
        init: function () {
            return getAssetRegistry(this.namespace)
                .then(this.doResetting.bind(this))
                .catch(function (error) {
                    throw new Error('Transaction (ResetShopping) process failed: ' + error);
                });
        },

        /**
         *
         * @param shoppingListRegistry
         */
        doResetting: function (shoppingListRegistry) {
            tx.shoppingList.orders = [];
            return shoppingListRegistry.update(tx.shoppingList);
        }
    });

    return new ResetShopping('org.eyes.znueni.ShoppingList');
}
