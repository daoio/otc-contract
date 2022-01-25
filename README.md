# Escrow-Maker
Smart contract that could create Escrow contracts.



![2022-01-18_19-10-09](https://user-images.githubusercontent.com/88685373/149975237-feeb9cc6-046f-4e8d-a6e5-44b99feac91d.png)


In Escrow contract UserA deposits ETH and userB deposits ERC20 token by choice to make trade. After currncies is deposited users signs this contract and change contract state, contract checks its state and then after all requirements passed UserA withdraw ERC20 tokens provided by UserB and UserB withdraw ETH provided by UserA. If users do not come to an agreement, they can return their funds if both users have not signed a contract.
