//
//  SZMentionsListener.swift
//  SZMentions_Swift
//
//  Created by Steven Zweier on 1/11/16.
//  Copyright © 2016 Steven Zweier. All rights reserved.
//

import UIKit

protocol SZMentionsManagerProtocol {
    /**
     @brief Called when the UITextView is editing a mention.

     @param MentionString the current text entered after the mention trigger.
     Generally used for filtering a mentions list.
     */
    func showMentionsListWithString(mentionsString: NSString)

    /**
     @brief Called when the UITextView is not editing a mention.
     */
    func hideMentionsList()
}

protocol SZCreateMentionProtocol {
    /**
     @brief The name of the mention to be added to the UITextView when selected.
     */
    var szMentionName: String {get}
}

public class SZMentionsListener: NSObject, UITextViewDelegate {
    /**
     @brief Trigger to start a mention. Default: @
     */
    var trigger: NSString = "@"

    /**
     @brief Text attributes to be applied to all text excluding mentions.
     */
    var defaultTextAttributes: [SZAttribute]?

    /**
     @brief Text attributes to be applied to mentions.
     */
    var mentionTextAttributes: [SZAttribute]?

    /**
     @brief The UITextView being handled by the SZMentionsListener
     */
    var mentionsTextView: UITextView

    /**
    @brief An optional delegate that can be used to handle all UITextView delegate
    methods after they've been handled by the SZMentionsListener
    */
    var delegate: UITextViewDelegate!

    /**
     @brief Manager in charge of handling the creation and dismissal of the mentions
     list.
     */
    var mentionsManager: SZMentionsManagerProtocol!

    /**
     @brief Mutable array list of mentions managed by listener, accessible via the
     public mentions property.
     */
    private var mutableMentions: [SZMention] = []
    /**
     @brief Array of mentions currently added to the textview
     */
    var mentions:[SZMention] {
        return mutableMentions
    }

    /**
     @brief Amount of time to delay between showMentions calls default:0.5
     */
    var cooldownInterval: NSTimeInterval = 0.5

    /**
     @brief Whether or not we should add a space after the mention, default: false
     */
    var spaceAfterMention: Bool = false

    /**
     @brief Range of mention currently being edited.
     */
    private var currentMentionRange: NSRange?

    /**
     @brief Whether or not we are currently editing a mention.
     */
    private var editingMention: Bool?
    
    /**
     @brief Allow us to edit text internally without triggering delegate
     */
    private var settingText: Bool?

    /**
     @brief String to filter by
     */
    private var filterString: String?

    /**
     @brief Timer to space out mentions requests
     */
    private var cooldownTimer: NSTimer?

    func addMention(mention: SZCreateMentionProtocol) {
        self.filterString = nil
        var displayName = mention.szMentionName

        if self.spaceAfterMention {
            displayName = displayName.stringByAppendingString(" ")
        }
        let mutableAttributedString = self.mentionsTextView.attributedText.mutableCopy()

        if (self.currentMentionRange != nil) {
            mutableAttributedString.mutableString.replaceCharactersInRange(self.currentMentionRange!, withString: displayName)
        }

        self.adjustMentions(self.currentMentionRange!, text: mention.szMentionName)

        self.currentMentionRange = NSMakeRange(self.currentMentionRange!.location, mention.szMentionName.characters.count)

        self.apply(self.mentionTextAttributes!, range: self.currentMentionRange!, mutableAttributedString: mutableAttributedString as! NSMutableAttributedString)

        let newRange = NSMakeRange(self.currentMentionRange!.location + self.currentMentionRange!.length - 1, 0)
        self.apply(self.defaultTextAttributes!, range:newRange , mutableAttributedString: mutableAttributedString as! NSMutableAttributedString)

        self.settingText = true
        self.mentionsTextView.attributedText = mutableAttributedString as! NSMutableAttributedString

        var selectedRange = NSMakeRange(self.currentMentionRange!.location + self.currentMentionRange!.length, 0)

        if self.spaceAfterMention {
            selectedRange.location++
        }

        self.mentionsTextView.selectedRange = selectedRange
        self.settingText = false

        let szmention = SZMention.init(mentionRange: self.currentMentionRange!, mentionObject: mention)
        self.mentionsManager.hideMentionsList()
        self.mutableMentions.append(szmention)
    }

    func adjustMentions(range : NSRange, text : String) {
        for mention in self.mentionsAfterTextEntry(range) {
            let rangeAdjustment = text.characters.count > 0 ? text.characters.count - (range.length > 0 ? range.length : 0) : -(range.length > 0 ? range.length : 0)
            mention.mentionRange = NSRange.init(location: mention.mentionRange.location + rangeAdjustment, length: mention.mentionRange.length)
        }
    }

    func mentionsAfterTextEntry(range: NSRange) -> [SZMention] {
        var mentionsAfterTextEntry = [SZMention]()

        for mention in self.mentions {

            if range.location + range.length <= mention.mentionRange.location {
                mentionsAfterTextEntry.append(mention)
            }
        }

        let immutableMentionsAfterTextEntry = mentionsAfterTextEntry

        return immutableMentionsAfterTextEntry
    }

    func handleEditingMention(mention: SZMention, textView: UITextView, range: NSRange, text: String) -> Bool {
        let mutableAttributedString = textView.attributedText.mutableCopy()

        self.apply(self.mentionTextAttributes!, range: mention.mentionRange, mutableAttributedString: mutableAttributedString as! NSMutableAttributedString)

        self.apply(self.defaultTextAttributes!, range: mention.mentionRange, mutableAttributedString: mutableAttributedString as! NSMutableAttributedString)

        mutableAttributedString.mutableString.replaceCharactersInRange(range, withString: text)

        self.settingText = true
        textView.attributedText = mutableAttributedString as! NSMutableAttributedString
        self.settingText = false
        textView.selectedRange = NSMakeRange(range.location + text.characters.count, 0)

        if self.delegate.respondsToSelector(Selector("textView:shouldChangeTextInRange:replacementText:")) {
            self.delegate.textView!(textView, shouldChangeTextInRange: range, replacementText: text)
        }

        return false
    }

    func defaultColor() -> SZAttribute {
        let defaultColor = SZAttribute.init(attributeName: NSForegroundColorAttributeName, attributeValue: UIColor.greenColor())

        return defaultColor
    }

    func mentionColor() -> SZAttribute {
        let mentionColor = SZAttribute.init(attributeName: NSForegroundColorAttributeName, attributeValue:UIColor.blueColor())

        return mentionColor
    }

    init(mentionTextView: UITextView) {
        mentionsTextView = mentionTextView
        super.init()
        mentionsTextView.delegate = self
        defaultTextAttributes = [defaultColor()]
        mentionTextAttributes = [mentionColor()]
    }

    func resetEmpty(textView: UITextView, text: String, range: NSRange) -> Bool {
        mutableMentions.removeAll()
        let mutableAttributedString = textView.attributedText.mutableCopy()
        mutableAttributedString.mutableString.replaceCharactersInRange(range, withString: text)
        self.apply(self.defaultTextAttributes!, range: NSRange(location: range.location, length: text.characters.count), mutableAttributedString: mutableAttributedString as! NSMutableAttributedString)
        self.settingText = true
        textView.attributedText = mutableAttributedString as! NSAttributedString
        self.settingText = false

        if (self.delegate.respondsToSelector(Selector("textView:shouldChangeTextInRange:replacementText:"))) {
            self.delegate.textView!(textView, shouldChangeTextInRange: range, replacementText: text)
        }

        self.textViewDidChange(textView)
        NSNotificationCenter.defaultCenter().postNotificationName(UITextViewTextDidChangeNotification, object: textView)

        return false
    }

    public func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
        assert((textView.delegate?.isEqual(self))!, "Textview delegate must be set equal to SZMentionsListener")

        if (self.settingText == true) {
            return false
        }

        return self.shouldAdjust(textView, range: range, text: text)
    }

    public func textViewDidChange(textView: UITextView) {
        if (self.delegate.respondsToSelector(Selector("textViewDidChange:"))) {
            self.delegate.textViewDidChange!(textView)
        }
    }

    func adjust(textView: UITextView, range: NSRange, text: String) {
        let substring = (textView.text as NSString).substringToIndex(range.location) as NSString

        var mentionEnabled = false

        let location = substring.rangeOfString(trigger as String, options: NSStringCompareOptions.BackwardsSearch).location

        if location != NSNotFound {
            mentionEnabled = location == 0

            if location > 0 {
                let substringRange = NSRange.init(location: location - 1, length: 1)
                mentionEnabled = substring.substringWithRange(substringRange) == " "
            }
        }

        let strings = substring.componentsSeparatedByString(" ")

        if ((strings.last! as NSString).rangeOfString(trigger as String).location != NSNotFound) {
            if mentionEnabled {
                self.currentMentionRange = (textView.text as NSString).rangeOfString(strings.last!, options: NSStringCompareOptions.BackwardsSearch)
                let mentionString = strings.last!.stringByAppendingString(text)
                self.filterString = mentionString.stringByReplacingOccurrencesOfString(trigger as String, withString: "")

                if self.filterString?.characters.count > 0 && self.cooldownTimer?.valid == true {
                    self.mentionsManager.showMentionsListWithString(self.filterString!)
                }
                self.activateCooldownTimer()
            } else {
                self.mentionsManager.hideMentionsList()
            }

        } else {
            self.mentionsManager.hideMentionsList()
        }
    }

    func shouldAdjust(textView: UITextView, range: NSRange, text: String) -> Bool {
        if (textView.text.characters.count == 0) {
            return self.resetEmpty(textView, text: text, range: range)
        }

        self.showHideMentionsList(textView, text: text)

        self.editingMention = false

        if let index = self.mutableMentions.indexOf(self.mentionBeingEdited(range)) {
            self.editingMention = true
            self.mutableMentions.removeAtIndex(index)
        }

        if self.needsToChangeToDefaultColor(textView, range: range) {
            return self.forceDefaultColor(textView, range: range, text: text)
        }

        if self.delegate.respondsToSelector(Selector("textView:shouldChangeTextInRange:replacementText:")) {
            return self.delegate.textView!(textView, shouldChangeTextInRange: range, replacementText: text)
        }

        return true
    }

    func forceDefaultColor(textView: UITextView, range: NSRange, text: String) -> Bool {
        let mutableAttributedString = textView.attributedText.mutableCopy() as! NSMutableAttributedString
        mutableAttributedString.mutableString.replaceCharactersInRange(range, withString: text)
        self.apply(self.defaultTextAttributes!, range: NSRange.init(location: range.location, length: text.characters.count), mutableAttributedString: mutableAttributedString)
        self.settingText = true
        textView.attributedText = mutableAttributedString
        self.settingText = false

        if range.length > 0 {
            textView.selectedRange = NSRange.init(location: range.location, length: 0)
        } else {
            textView.selectedRange = NSRange.init(location: range.location + text.characters.count, length: 0)
        }

        return false
    }

    func isMentionAt(index: NSInteger, textView: UITextView) -> Bool {
        if (index < 0 || textView.attributedText.length <= index) {
            return false
        }

        let attribute = self.mentionTextAttributes![0]
        let effectiveRange = NSRangePointer.init(bitPattern: 0)

        return (textView.attributedText.attribute(attribute.attributeName, atIndex: index, effectiveRange: effectiveRange)?.isEqual(attribute.attributeValue))!
    }

    func needsToChangeToDefaultColor(textView: UITextView, range: NSRange) -> Bool {
        let isAheadOfMention = range.location > 0 &&
        self.isMentionAt(range.location - 1, textView: textView)
        let isAtStartOfTextViewAndIsTouchingMention = range.location == 0 &&
        self.isMentionAt(range.location + 1, textView: textView)

        return isAheadOfMention || isAtStartOfTextViewAndIsTouchingMention
    }

    func mentionBeingEdited(range: NSRange) -> SZMention {
        var editedMention: SZMention?

        for mention in self.mentions {
            let currentMentionRange = mention.mentionRange
            if (NSIntersectionRange(range, currentMentionRange).length > 0 ||
                (range.length == 0 &&
                    range.location > currentMentionRange.location &&
                    range.location < currentMentionRange.length + currentMentionRange.location))
                 {
                    editedMention = mention
            }
        }

        return editedMention!
    }

    func showHideMentionsList(textView: UITextView, text: String) {

        if (text == " " ||
            (text.characters.count > 0 &&
            text.characters.last! == " ")) {
                self.mentionsManager!.hideMentionsList()
        }
    }

    func apply(attributes: [SZAttribute], range: NSRange, mutableAttributedString: NSMutableAttributedString) {
        for attribute in attributes {
            mutableAttributedString.addAttribute(attribute.attributeName, value: attribute.attributeValue, range: range)
        }
    }

    func cooldownTimerFired(timer: NSTimer) {
        if ((self.filterString?.characters.count) != nil) {
            self.mentionsManager.showMentionsListWithString(self.filterString!)
        }
    }

    func activateCooldownTimer() {
        self.cooldownTimer?.invalidate()

        let timer = NSTimer.init(timeInterval: self.cooldownInterval, target: self, selector: Selector("cooldownTimerFired:"), userInfo: nil, repeats: false)
        self.cooldownTimer = timer
        NSRunLoop.mainRunLoop().addTimer(timer, forMode: NSDefaultRunLoopMode)
    }

    public func textView(textView: UITextView, shouldInteractWithTextAttachment textAttachment: NSTextAttachment, inRange characterRange: NSRange) -> Bool {
        if self.delegate.respondsToSelector(Selector("textView:shouldInteractWithTextAttachment:inRange:")) {
            return self.delegate.textView!(textView, shouldInteractWithTextAttachment: textAttachment, inRange: characterRange)
        }

        return true
    }

    public func textView(textView: UITextView, shouldInteractWithURL URL: NSURL, inRange characterRange: NSRange) -> Bool {
        if self.delegate.respondsToSelector(Selector("textView:shouldInteractWithURL:inRange:")) {
            return self.delegate.textView!(textView, shouldInteractWithURL: URL, inRange: characterRange)
        }

        return true
    }

    public func textViewDidBeginEditing(textView: UITextView) {
        if self.delegate.respondsToSelector(Selector("textViewDidBeginEditing:")) {
            self.delegate.textViewDidBeginEditing!(textView)
        }
    }

    public func textViewDidChangeSelection(textView: UITextView) {
        if self.delegate.respondsToSelector(Selector("textViewDidChangeSelection:")) {
            self.delegate.textViewDidChangeSelection!(textView)
        }
    }

    public func textViewDidEndEditing(textView: UITextView) {
        if self.delegate.respondsToSelector(Selector("textViewDidEndEditing:")) {
            self.delegate.textViewDidEndEditing!(textView)
        }
    }

    public func textViewShouldBeginEditing(textView: UITextView) -> Bool {
        if self.delegate.respondsToSelector(Selector("textViewShouldBeginEditing:")) {
            return self.delegate.textViewShouldBeginEditing!(textView)
        }

        return true
    }

    public func textViewShouldEndEditing(textView: UITextView) -> Bool {
        if self.delegate.respondsToSelector(Selector("textViewShouldEndEditing")) {
            return self.delegate.textViewShouldEndEditing!(textView)
        }

        return true
    }
}
