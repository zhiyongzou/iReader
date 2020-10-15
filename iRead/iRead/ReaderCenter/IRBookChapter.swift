//
//  IRBookChapter.swift
//  iRead
//
//  Created by zzyong on 2020/9/28.
//  Copyright © 2020 zzyong. All rights reserved.
//

import UIKit
import IRCommonLib

class IRBookChapter: NSObject {
    
    /// 文字颜色
    let textColor = IRReaderConfig.textColor
    /// 文字大小
    let textSize = IRReaderConfig.textSize
    /// 章节页列表
    var pageList: [IRBookPage]?
    /// 章节标题
    var title: String?
    /// 章节索引
    var chapterIdx: Int = 1
    /// 内容
    var content: NSAttributedString?
    
    
    public convenience init(withTocRefrence refrence: FRTocReference, chapterIndex: Int) {
        
        self.init()
        self.title = refrence.title
        self.chapterIdx = chapterIndex
        
        guard let fullHref = refrence.resource?.fullHref else { return }
        let baseUrl = URL.init(fileURLWithPath: fullHref)
        guard let htmlData = try? Data.init(contentsOf: baseUrl) else { return }
        
        let options: [String : Any] = [
            NSBaseURLDocumentOption: baseUrl,
            DTMaxImageSize: NSValue.init(cgSize: IRReaderConfig.pageSzie),
            NSTextSizeMultiplierDocumentOption: IRReaderConfig.textSizeMultiplier,
            DTDefaultLineHeightMultiplier: IRReaderConfig.lineHeightMultiple,
            DTDefaultLinkColor: "purple",
            DTDefaultTextColor: textColor,
            DTDefaultFontSize: textSize
        ]
        // as 用法 https://developer.apple.com/swift/blog/?id=23
        // as? 或 as! 向下转到它的子类
        let htmlString = NSAttributedString.init(htmlData: htmlData, options: options, documentAttributes: nil).mutableCopy() as! NSMutableAttributedString
        let tempHtmlString = htmlString.mutableCopy() as? NSMutableAttributedString
        
        // 段落样式调整
        tempHtmlString?.enumerateAttribute(.paragraphStyle, in: NSMakeRange(0, htmlString.length), options: [.longestEffectiveRangeNotRequired]) { (value, range, stop) in
            // is: 检查一个实例是否属于特定子类型
            if value is NSParagraphStyle {
                let paragraphStyle: NSMutableParagraphStyle = (value as! NSParagraphStyle).mutableCopy() as! NSMutableParagraphStyle
                paragraphStyle.paragraphSpacing = IRReaderConfig.paragraphSpacing
                paragraphStyle.lineSpacing = IRReaderConfig.lineSpacing
                htmlString.removeAttribute(.paragraphStyle, range: range)
                htmlString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            }
        }
        
        let textLayout = DTCoreTextLayouter.init(attributedString: htmlString)
        let textRect = CGRect.init(origin: CGPoint.zero, size: IRReaderConfig.pageSzie)
        var layoutFrame = textLayout?.layoutFrame(with: textRect, range: NSMakeRange(0, htmlString.length))
        var visibleRange: NSRange! = layoutFrame?.visibleStringRange()
        var pageOffset = visibleRange.location + visibleRange.length
        var pageCount: Int = 1
        var pageList = [IRBookPage]()
        while pageOffset <= htmlString.length && pageOffset != 0 {
            
            let content = htmlString.attributedSubstring(from: visibleRange)
            let textContent = content.string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            // 空白页判断
            if textContent.count > 0 {
                let pageModel = IRBookPage.bookPage(withPageIdx: pageCount - 1, chapterIdx: chapterIndex)
                pageModel.content = content
                pageCount += 1;
                pageList.append(pageModel)
            }
            
            var nextPageNeedFirstLineHeadIndent = true
            if let paragraphRanges = layoutFrame?.paragraphRanges {
                for rangeValue in paragraphRanges {
                    let range = (rangeValue as! NSValue).rangeValue
                    if (pageOffset > range.location && pageOffset < (range.location + range.length)) {
                        nextPageNeedFirstLineHeadIndent = false
                        break
                    }
                }
            }
            
            layoutFrame = textLayout?.layoutFrame(with: textRect, range: NSMakeRange(pageOffset, htmlString.length - pageOffset))
            if layoutFrame == nil {
                break
            }
            
            if !nextPageNeedFirstLineHeadIndent {
                let firstLine: DTCoreTextLayoutLine = layoutFrame?.lines.first as! DTCoreTextLayoutLine
                let firstLineRange = firstLine.stringRange()
                let firstLineAtt = htmlString.attributedSubstring(from: firstLineRange)
                let originalStyle = firstLineAtt.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                if (originalStyle != nil) {
                    let firstLineStyle: NSMutableParagraphStyle = (originalStyle as! NSParagraphStyle).mutableCopy() as! NSMutableParagraphStyle
                    firstLineStyle.firstLineHeadIndent = firstLineStyle.headIndent;
                    htmlString.addAttributes([.paragraphStyle: firstLineStyle], range: firstLineRange)
                }
            }
            
            visibleRange = layoutFrame?.visibleStringRange()
            if (visibleRange.location == NSNotFound) {
                pageOffset = 0;
            } else {
                pageOffset = visibleRange.location + visibleRange.length;
            }
        }
        
        self.pageList = pageList
    }
}
