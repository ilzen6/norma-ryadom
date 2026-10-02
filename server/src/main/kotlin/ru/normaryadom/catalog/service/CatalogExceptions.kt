package ru.normaryadom.catalog.service

import ru.normaryadom.common.error.NotFoundException

class ChainNotFoundException(
    chainId: Long,
) : NotFoundException("chain", chainId)

class VenueNotFoundException(
    venueId: Long,
) : NotFoundException("venue", venueId)

class MenuItemNotFoundException(
    itemId: Long,
) : NotFoundException("menu-item", itemId)

class ChainNameTakenException(
    val chainName: String,
) : RuntimeException("Chain name is already taken")
