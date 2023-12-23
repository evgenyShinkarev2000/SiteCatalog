// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.22;

import "@openzeppelin/contracts/utils/Strings.sol";

// основной контракт, с которым происходит взаимодействие
contract SiteCatalog {
    // создаем хранилище сайтов
    SiteStorage private sites = new SiteStorage();
    // проверка имена сайта или тега
    modifier nameIsValid(string calldata name){
        bytes memory nameBytes = bytes(name);
        if (nameBytes.length == 0){
            revert("name's length must be > 0");
        }
        for (uint i = 0; i < nameBytes.length; i++){
            // 0x3B ";"
            if (nameBytes[i] == 0x3B){
                revert("name can't contain \";\"");
            }
        }
        _;
    }

    constructor() {}
    // добавление сайта
    function addSite(string calldata name) external nameIsValid(name){
        sites.add(name);
    }
    // добавление тега
    function addTagToSite(string calldata siteName, string calldata tag) external nameIsValid(tag) {
        sites.get(siteName).tagStorage().add(tag);
    }
    // получение всех сайтов с тегами в специальном формате
    function getSites() public view returns (string[] memory) {
        return sites.getFormatedSites();
    }
    // голосование нужно для защиты от спамеров и определения популярности сайта
    // проголосовать за сайт, вес голоса считается ~как стоимость транзакции и msg.value
    function votePositiveSite(string calldata siteName) external payable {
        sites.get(siteName).positiveVotes().votePay{value: msg.value}();
    }
    // проголосовать против сайта
    function voteNegativeSite(string calldata siteName) external payable {
        sites.get(siteName).negativeVotes().votePay{value: msg.value}();
    }
    // проголосовать за тег сайта
    function votePositiveTag(string calldata siteName, string calldata tagName) external payable {
        sites.get(siteName).tagStorage().get(tagName).positiveVotes().votePay{value: msg.value}();
    }
    // проголосовать проти тега сайта
    function voteNegativeTag(string calldata siteName, string calldata tagName) external payable {
        sites.get(siteName).tagStorage().get(tagName).negativeVotes().votePay{value: msg.value}();
    }
}
// хранилище сайтов
contract SiteStorage {
    // создаем мапу для получения информации о сайте по его имени
    mapping (string => SiteInfo) private siteNameToSiteInfo;
    // создаем мапу для проверки, был ли сайт уже добавлен
    mapping (string => bool) private siteHashSet;
    // массив всех сайтов, не содержит сайтов с одинаковыми именами 
    SiteInfo[] private sites;
    // получение информации о сайте по его имени
    function get(string calldata siteName) external view returns (SiteInfo){
        require(contains(siteName), "Site not exist");
        return siteNameToSiteInfo[siteName];
    }
    // добавление сайта
    function add(string calldata siteName) external {
        require(!contains(siteName), "Site alredy exist");
        // используем контракт, чтобы во всех коллекциях была ссылка на один и тот же объект, а не копии
        SiteInfo siteInfo = new SiteInfo(siteName);
        siteHashSet[siteName] = true;
        siteNameToSiteInfo[siteName] = siteInfo;
        sites.push(siteInfo);
    }
    // получение всех сайтов
    function getSites() external view returns (SiteInfo[] memory){
        return sites;
    }
    // получение всех сайтов в специальном формате
    function getFormatedSites() external view returns (string[] memory){
        string[] memory result = new string[](sites.length);
        for (uint i = 0; i < sites.length; i++) 
        {
            result[i] = string(sites[i].getFormated());
        }
        return result;
    }
    // проверка, был ли сайт добавлен
    function contains(string calldata siteName) private view returns (bool) {
        return siteHashSet[siteName];
    }
}
// информация о сайте
contract SiteInfo {
    // хранилище тегов сайта
    TagStorage public tagStorage = new TagStorage();
    // имя сайта
    string public name;
    // голоса за сайт
    VotingPoints public positiveVotes = new VotingPoints();
    // голоса против сайта
    VotingPoints public negativeVotes = new VotingPoints();

    constructor(string memory _name) {
        name = _name;
    }
    // получение информации о сайта в специальном формате. <имя сайта>;<голоса за>.<голоса против>;<тег>;<голоса за>.<голоса против>;...
    function getFormated() external view returns(string memory) {
        bytes memory stringBytes = bytes(name);
        stringBytes = abi.encodePacked(stringBytes, ";", toString(positiveVotes.get()), ".", toString(negativeVotes.get()));
        TagInfo[] memory tags = tagStorage.getTags();
        for(uint i; i < tags.length; i++){
            stringBytes = abi.encodePacked(
                stringBytes, ";", tags[i].name(), ";", 
                toString(tags[i].positiveVotes().get()) , ".",  toString(tags[i].negativeVotes().get())
            );
        }
        return string(stringBytes);
    }
    // перевод числа в строку, обертка на библиотекой 
    function toString(uint number) private pure returns(string memory) {
        return Strings.toString(number);
    }
}
// хранилище тегов
contract TagStorage {
    // мапа для получение информации о теги по имени
    mapping (string => TagInfo) private tagNameToTagInfo;
    // мапа для проверки, был ли тег добавлен
    mapping (string => bool) private tagHashSet;
    // коллекция всех тегов сайта, имена уникальны
    TagInfo[] private tags;
    // получение информации о теги по имени
    function get(string calldata nameTag) external view returns (TagInfo){
        require(contains(nameTag), "Tag not exist");
        return tagNameToTagInfo[nameTag];
    }
    // добавление тега
    function add(string calldata tagName) external {
        require(!contains(tagName), "Tag alredy exist");
        // используем контракт, чтобы во всех коллекциях была ссылка на один и тот же объект, а не копии
        TagInfo tagInfo = new TagInfo(tagName);
        tagHashSet[tagName] = true;
        tagNameToTagInfo[tagName] = tagInfo;
        tags.push(tagInfo);
    }
    // получение всех тегов сайта
    function getTags() external view returns (TagInfo[] memory){
        return tags;
    }
    // был ли тег добавлен
    function contains(string calldata tag) private view returns (bool){
        return tagHashSet[tag];
    }
}
// информация о теге
contract TagInfo {
    // имя тега
    string public name;
    // голоса за тег
    VotingPoints public positiveVotes = new VotingPoints();
    // голоса против тега
    VotingPoints public negativeVotes = new VotingPoints();

    constructor(string memory _name) {
        name = _name;
    }
}
// хранилище веса голосов
contract VotingPoints {
    // сколько эфира было затрачено на голосование
    uint256 private weiTransferred = 0;

    constructor() {
    }
    // голосовать с добавлением msg.value к весу голоса
    function votePay() external payable {
        // msg.value уничтожается пересылкой адрес 0x0, к которому не существует приватного ключа
        address payable burn = payable(address(0));
        burn.transfer(msg.value);
        // добавляем вес голоса. Рассчитывается не точно, т. к. операция изменения значения в storage не учитывается.
        weiTransferred = weiTransferred + msg.value + gasleft();
    }
    // получить вес голосов
    function get() external view returns (uint256){
        return weiTransferred;
    }
}